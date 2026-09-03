// Copyright Epic Games, Inc. All Rights Reserved.

#include "Phases/Phase1_DirectLighting/Phase1DirectLightingActor.h"

#include "Camera/CameraComponent.h"
#include "Components/SceneComponent.h"
#include "Components/SpotLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/PlayerController.h"
#include "HAL/IConsoleManager.h"
#include "HAL/PlatformMisc.h"
#include "Kismet/GameplayStatics.h"
#include "Kismet/KismetMathLibrary.h"
#include "Materials/MaterialInterface.h"
#include "Misc/CommandLine.h"
#include "RenderPipelineLab.h"
#include "TimerManager.h"
#include "UObject/ConstructorHelpers.h"

namespace Phase1DirectLighting
{
	const FVector PlaneLocation(0.0, 0.0, 0.0);
	const FVector PlaneScale(10.0, 10.0, 1.0);
	const FVector BoxLocation(0.0, 0.0, 50.0);
	const FVector BoxScale(1.0, 1.0, 1.0);
	const FVector SpotLocation(-300.0, -200.0, 400.0);
	const FVector ReceiverTarget(100.0, 60.0, 1.0);
	const FVector CameraLocation(0.0, -900.0, 500.0);
	const FVector CameraTarget(60.0, 0.0, 30.0);
	constexpr float CameraFov = 60.0f;
	constexpr float SpotIntensity = 300.0f;
	constexpr float SpotRadius = 1500.0f;
	constexpr float SpotInnerCone = 20.0f;
	constexpr float SpotOuterCone = 35.0f;

	struct FExpectedIntCVar
	{
		const TCHAR* Name;
		int32 Expected;
	};

	const FExpectedIntCVar RequiredIntCVars[] = {
		{TEXT("r.ForwardShading"), 0},
		{TEXT("r.UseClusteredDeferredShading_ToBeRemoved"), 0},
		{TEXT("r.Shadow.Virtual.Enable"), 0},
		{TEXT("r.Shadow.FilterMethod"), 0},
		{TEXT("r.Shadow.CacheWholeSceneShadows"), 0},
		{TEXT("r.Nanite.ProjectEnabled"), 0},
		{TEXT("r.Substrate"), 0},
		{TEXT("r.MegaLights.Allowed"), 0},
		{TEXT("r.RayTracing"), 0},
		{TEXT("r.DynamicGlobalIlluminationMethod"), 0},
		{TEXT("r.ReflectionMethod"), 0},
		{TEXT("r.GenerateMeshDistanceFields"), 0},
		{TEXT("r.AllowStaticLighting"), 0},
		{TEXT("sg.ViewDistanceQuality"), 3},
		{TEXT("sg.AntiAliasingQuality"), 3},
		{TEXT("sg.ShadowQuality"), 3},
		{TEXT("sg.GlobalIlluminationQuality"), 3},
		{TEXT("sg.ReflectionQuality"), 3},
		{TEXT("sg.PostProcessQuality"), 3},
		{TEXT("sg.TextureQuality"), 3},
		{TEXT("sg.EffectsQuality"), 3},
		{TEXT("sg.FoliageQuality"), 3},
		{TEXT("sg.ShadingQuality"), 3},
		{TEXT("sg.LandscapeQuality"), 3}
	};
}

APhase1DirectLightingActor::APhase1DirectLightingActor()
{
	PrimaryActorTick.bCanEverTick = false;

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeFinder(
		TEXT("/Engine/BasicShapes/Cube.Cube"));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> PlaneFinder(
		TEXT("/Engine/BasicShapes/Plane.Plane"));
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> MaterialFinder(
		TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"));
	check(CubeFinder.Succeeded());
	check(PlaneFinder.Succeeded());
	check(MaterialFinder.Succeeded());

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	SceneRoot->SetMobility(EComponentMobility::Static);
	SetRootComponent(SceneRoot);

	BoxCaster = CreateDefaultSubobject<UStaticMeshComponent>(
		TEXT("Phase1_BoxCaster"));
	BoxCaster->SetupAttachment(SceneRoot);
	BoxCaster->SetStaticMesh(CubeFinder.Object);
	BoxCaster->SetMaterial(0, MaterialFinder.Object);
	BoxCaster->SetMobility(EComponentMobility::Static);
	BoxCaster->SetCastShadow(true);
	BoxCaster->SetRelativeLocation(Phase1DirectLighting::BoxLocation);
	BoxCaster->SetRelativeScale3D(Phase1DirectLighting::BoxScale);
	BoxCaster->ComponentTags.AddUnique(FName(TEXT("RenderPipelineLab.Phase1.BoxCaster")));

	PlaneReceiver = CreateDefaultSubobject<UStaticMeshComponent>(
		TEXT("Phase1_PlaneReceiver"));
	PlaneReceiver->SetupAttachment(SceneRoot);
	PlaneReceiver->SetStaticMesh(PlaneFinder.Object);
	PlaneReceiver->SetMaterial(0, MaterialFinder.Object);
	PlaneReceiver->SetMobility(EComponentMobility::Static);
	PlaneReceiver->SetCastShadow(false);
	PlaneReceiver->SetRelativeLocation(Phase1DirectLighting::PlaneLocation);
	PlaneReceiver->SetRelativeScale3D(Phase1DirectLighting::PlaneScale);
	PlaneReceiver->ComponentTags.AddUnique(
		FName(TEXT("RenderPipelineLab.Phase1.PlaneReceiver")));

	SpotLight = CreateDefaultSubobject<USpotLightComponent>(
		TEXT("Phase1_MovableSpotLight"));
	SpotLight->SetupAttachment(SceneRoot);
	SpotLight->SetMobility(EComponentMobility::Movable);
	SpotLight->SetIntensityUnits(ELightUnits::Lumens);
	SpotLight->SetIntensity(Phase1DirectLighting::SpotIntensity);
	SpotLight->SetLightColor(FLinearColor::White);
	SpotLight->SetAttenuationRadius(Phase1DirectLighting::SpotRadius);
	SpotLight->SetInnerConeAngle(Phase1DirectLighting::SpotInnerCone);
	SpotLight->SetOuterConeAngle(Phase1DirectLighting::SpotOuterCone);
	SpotLight->SetSourceRadius(0.0f);
	SpotLight->SetSoftSourceRadius(0.0f);
	SpotLight->SetSourceLength(0.0f);
	SpotLight->ContactShadowLength = 0.0f;
	SpotLight->ContactShadowLengthInWS = 0;
	SpotLight->SetLightingChannels(true, false, false);
	SpotLight->SetIESTexture(nullptr);
	SpotLight->SetLightFunctionMaterial(nullptr);
	SpotLight->bAllowMegaLights = false;
	SpotLight->SetCastShadows(true);
	SpotLight->SetRelativeLocation(Phase1DirectLighting::SpotLocation);
	SpotLight->SetRelativeRotation(UKismetMathLibrary::FindLookAtRotation(
		Phase1DirectLighting::SpotLocation,
		Phase1DirectLighting::ReceiverTarget));

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Phase1_FixedCamera"));
	Camera->SetupAttachment(SceneRoot);
	Camera->SetRelativeLocation(Phase1DirectLighting::CameraLocation);
	Camera->SetRelativeRotation(UKismetMathLibrary::FindLookAtRotation(
		Phase1DirectLighting::CameraLocation,
		Phase1DirectLighting::CameraTarget));
	Camera->FieldOfView = Phase1DirectLighting::CameraFov;
}

void APhase1DirectLightingActor::BeginPlay()
{
	Super::BeginPlay();

	const TOptional<EPhase1ShadowMode> ParsedMode =
		ParseShadowMode(FCommandLine::Get());
	if (!ParsedMode.IsSet())
	{
		UE_LOG(
			LogRenderPipelineLab,
			Error,
			TEXT("Phase=Phase1 Stage=StartupFailed Reason=InvalidShadowMode"));
		FPlatformMisc::RequestExitWithStatus(true, 3);
		return;
	}
	ShadowMode = ParsedMode.GetValue();
	SpotLight->SetCastShadows(ShadowMode == EPhase1ShadowMode::On);

	APlayerController* PlayerController =
		UGameplayStatics::GetPlayerController(this, 0);
	if (!PlayerController)
	{
		UE_LOG(
			LogRenderPipelineLab,
			Error,
			TEXT("Phase=Phase1 Stage=ReadyFailed Reason=NoPlayerController"));
		return;
	}
	PlayerController->SetViewTarget(this);

	GetWorldTimerManager().SetTimer(
		ReadyTimer,
		this,
		&APhase1DirectLightingActor::ValidateAndLogReady,
		0.25f,
		false);
}

TOptional<EPhase1ShadowMode> APhase1DirectLightingActor::ParseShadowMode(
	const TCHAR* CommandLine)
{
	FString Value;
	if (!FParse::Value(CommandLine, TEXT("Phase1Shadow="), Value))
	{
		return EPhase1ShadowMode::On;
	}
	if (Value.Equals(TEXT("On"), ESearchCase::IgnoreCase))
	{
		return EPhase1ShadowMode::On;
	}
	if (Value.Equals(TEXT("Off"), ESearchCase::IgnoreCase))
	{
		return EPhase1ShadowMode::Off;
	}
	return {};
}

FVector APhase1DirectLightingActor::GetReceiverTargetWorldPosition()
{
	return Phase1DirectLighting::ReceiverTarget;
}

bool APhase1DirectLightingActor::ValidateBaselineAndLog() const
{
	bool bValid = true;
	for (const Phase1DirectLighting::FExpectedIntCVar& Required :
		Phase1DirectLighting::RequiredIntCVars)
	{
		const IConsoleVariable* CVar =
			IConsoleManager::Get().FindConsoleVariable(Required.Name);
		if (!CVar)
		{
			UE_LOG(
				LogRenderPipelineLab,
				Error,
				TEXT("Phase=Phase1 BaselineCVar Name=%s Value=Missing Expected=%d"),
				Required.Name,
				Required.Expected);
			bValid = false;
			continue;
		}
		const int32 Value = CVar->GetInt();
		UE_LOG(
			LogRenderPipelineLab,
			Display,
			TEXT("Phase=Phase1 BaselineCVar Name=%s Value=%d Expected=%d"),
			Required.Name,
			Value,
			Required.Expected);
		bValid &= Value == Required.Expected;
	}

	const IConsoleVariable* ResolutionQuality =
		IConsoleManager::Get().FindConsoleVariable(TEXT("sg.ResolutionQuality"));
	if (!ResolutionQuality)
	{
		UE_LOG(
			LogRenderPipelineLab,
			Error,
			TEXT("Phase=Phase1 BaselineCVar Name=sg.ResolutionQuality Value=Missing Expected=RecordOnly"));
		bValid = false;
	}
	else
	{
		const float Value = ResolutionQuality->GetFloat();
		UE_LOG(
			LogRenderPipelineLab,
			Display,
			TEXT("Phase=Phase1 BaselineCVar Name=sg.ResolutionQuality Value=%.2f Expected=RecordOnly"),
			Value);
	}

	const IConsoleVariable* ClusteredProjectSupport =
		IConsoleManager::Get().FindConsoleVariable(
			TEXT("r.ClusteredDeferredShading.EnableForProject"));
	UE_LOG(
		LogRenderPipelineLab,
		Display,
		TEXT("Phase=Phase1 BaselineCVar Name=r.ClusteredDeferredShading.EnableForProject Value=%s Expected=RecordOnly"),
		ClusteredProjectSupport
			? *ClusteredProjectSupport->GetString()
			: TEXT("Missing"));

	return bValid;
}

void APhase1DirectLightingActor::ValidateAndLogReady()
{
	APlayerController* PlayerController =
		UGameplayStatics::GetPlayerController(this, 0);
	if (!PlayerController)
	{
		UE_LOG(
			LogRenderPipelineLab,
			Error,
			TEXT("Phase=Phase1 Stage=ReadyFailed Reason=NoPlayerController"));
		return;
	}

	int32 ViewportX = 0;
	int32 ViewportY = 0;
	PlayerController->GetViewportSize(ViewportX, ViewportY);
	FVector2D ScreenPosition;
	const bool bProjected = PlayerController->ProjectWorldLocationToScreen(
		Phase1DirectLighting::ReceiverTarget,
		ScreenPosition,
		true);
	const FIntPoint TargetPixel(
		FMath::RoundToInt(ScreenPosition.X),
		FMath::RoundToInt(ScreenPosition.Y));
	const bool bInViewport = bProjected &&
		TargetPixel.X >= 0 && TargetPixel.X < ViewportX &&
		TargetPixel.Y >= 0 && TargetPixel.Y < ViewportY;
	const bool bBaselineValid = ValidateBaselineAndLog();

	if (ViewportX != 1280 || ViewportY != 1080 || !bInViewport ||
		!bBaselineValid)
	{
		UE_LOG(
			LogRenderPipelineLab,
			Error,
			TEXT("Phase=Phase1 Stage=ReadyFailed Reason=BaselineOrProjection Viewport=%dx%d Projected=%d InViewport=%d Baseline=%d"),
			ViewportX,
			ViewportY,
			bProjected ? 1 : 0,
			bInViewport ? 1 : 0,
			bBaselineValid ? 1 : 0);
		return;
	}

	UE_LOG(
		LogRenderPipelineLab,
		Display,
		TEXT("Phase=Phase1 ShadowMode=%s TargetWorldPosition=%s TargetScreenPosition=(%d,%d) Viewport=%dx%d FeatureLevel=%s(%d)"),
		ShadowMode == EPhase1ShadowMode::On ? TEXT("On") : TEXT("Off"),
		*Phase1DirectLighting::ReceiverTarget.ToCompactString(),
		TargetPixel.X,
		TargetPixel.Y,
		ViewportX,
		ViewportY,
		GetWorld()->GetFeatureLevel() == ERHIFeatureLevel::SM6
			? TEXT("SM6")
			: TEXT("Other"),
		static_cast<int32>(GetWorld()->GetFeatureLevel()));
	UE_LOG(
		LogRenderPipelineLab,
		Display,
		TEXT("Phase=Phase1 BoxTransform=%s PlaneTransform=%s SpotTransform=%s CameraTransform=%s SpotIntensity=%.2f SpotRadius=%.2f SpotInnerCone=%.2f SpotOuterCone=%.2f CastShadows=%d"),
		*BoxCaster->GetComponentTransform().ToHumanReadableString(),
		*PlaneReceiver->GetComponentTransform().ToHumanReadableString(),
		*SpotLight->GetComponentTransform().ToHumanReadableString(),
		*Camera->GetComponentTransform().ToHumanReadableString(),
		SpotLight->Intensity,
		SpotLight->AttenuationRadius,
		SpotLight->InnerConeAngle,
		SpotLight->OuterConeAngle,
		SpotLight->CastShadows ? 1 : 0);
	LogPhaseReady();
	SchedulePixCaptureIfRequested();
}
