// Copyright Epic Games, Inc. All Rights Reserved.

#include "RenderPipelineProbeActor.h"

#include "Camera/CameraComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/InputComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/PlayerController.h"
#include "InputCoreTypes.h"
#include "Kismet/GameplayStatics.h"
#include "Materials/MaterialInterface.h"
#include "Misc/CommandLine.h"
#include "TimerManager.h"
#include "UObject/ConstructorHelpers.h"

DEFINE_LOG_CATEGORY(LogRenderPipelineProbe);

namespace RenderPipelineProbe
{
	const FName MeshObjectName(TEXT("RenderPipelineProbe_Box"));
	const FName MeshDebugTag(TEXT("RenderPipelineProbe.Box"));
	const FVector InitialLocation(0.0, 0.0, 0.0);
	const FVector OffsetLocation(0.0, 150.0, 0.0);
}

ARenderPipelineProbeActor::ARenderPipelineProbeActor()
{
	PrimaryActorTick.bCanEverTick = false;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	SetRootComponent(SceneRoot);

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeFinder(
		TEXT("/Engine/BasicShapes/Cube.Cube"));
	CubeAsset = CubeFinder.Object;
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> MaterialFinder(
		TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"));
	SimpleMaterial = MaterialFinder.Object;

	ProbeMesh = CreateDefaultSubobject<UStaticMeshComponent>(
		RenderPipelineProbe::MeshObjectName);
	ConfigureProbeMesh(*ProbeMesh);

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("ProbeCamera"));
	Camera->SetupAttachment(SceneRoot);
	Camera->SetRelativeLocation(FVector(-350.0, 0.0, 100.0));
	Camera->SetRelativeRotation(FRotator(-12.0, 0.0, 0.0));
	Camera->FieldOfView = 60.0f;

	DirectionalLight = CreateDefaultSubobject<UDirectionalLightComponent>(
		TEXT("ProbeDirectionalLight"));
	DirectionalLight->SetupAttachment(SceneRoot);
	DirectionalLight->SetRelativeRotation(FRotator(-35.0, -30.0, 0.0));
	DirectionalLight->SetIntensity(3.0f);
	DirectionalLight->SetCastShadows(false);
}

void ARenderPipelineProbeActor::BeginPlay()
{
	Super::BeginPlay();

	APlayerController* PlayerController =
		UGameplayStatics::GetPlayerController(this, 0);
	if (!PlayerController)
	{
		UE_LOG(LogRenderPipelineProbe, Error,
			TEXT("Stage=ReadyFailed Reason=NoPlayerController"));
		return;
	}

	PlayerController->SetViewTarget(this);
	EnableInput(PlayerController);
	if (!InputComponent)
	{
		UE_LOG(LogRenderPipelineProbe, Error,
			TEXT("Stage=ReadyFailed Reason=NoInputComponent"));
		return;
	}

	InputComponent->BindKey(EKeys::One, IE_Pressed, this,
		&ARenderPipelineProbeActor::ToggleProbeTransform);
	InputComponent->BindKey(EKeys::Two, IE_Pressed, this,
		&ARenderPipelineProbeActor::RebuildProbeRenderState);
	InputComponent->BindKey(EKeys::Three, IE_Pressed, this,
		&ARenderPipelineProbeActor::DestroyProbeMesh);
	InputComponent->BindKey(EKeys::Four, IE_Pressed, this,
		&ARenderPipelineProbeActor::CreateProbeMesh);

	UE_LOG(LogRenderPipelineProbe, Display,
		TEXT("Stage=Ready Component=%s"), *ProbeMesh->GetName());

	if (FParse::Param(FCommandLine::Get(), TEXT("pixautocapture")))
	{
		GetWorldTimerManager().SetTimer(
			PixCaptureTimer,
			this,
			&ARenderPipelineProbeActor::TriggerPixCapture,
			5.0f,
			false);
		UE_LOG(LogRenderPipelineProbe, Display,
			TEXT("Stage=PixCaptureScheduled DelaySeconds=5"));
	}
}

void ARenderPipelineProbeActor::TriggerPixCapture()
{
	UE_LOG(LogRenderPipelineProbe, Display,
		TEXT("Stage=PixCaptureRequested Command=pix.GpuCaptureFrame"));
	if (!GEngine->Exec(GetWorld(), TEXT("pix.GpuCaptureFrame")))
	{
		UE_LOG(LogRenderPipelineProbe, Error,
			TEXT("Stage=PixCaptureFailed Reason=CommandUnavailable"));
	}
}

void ARenderPipelineProbeActor::ToggleProbeTransform()
{
	if (!ProbeMesh)
	{
		return;
	}

	bProbeAtOffset = !bProbeAtOffset;
	ProbeMesh->SetRelativeLocation(
		bProbeAtOffset
			? RenderPipelineProbe::OffsetLocation
			: RenderPipelineProbe::InitialLocation);
	UE_LOG(LogRenderPipelineProbe, Display,
		TEXT("Stage=Transform Component=%s Offset=%d"),
		*ProbeMesh->GetName(),
		bProbeAtOffset ? 1 : 0);
}

void ARenderPipelineProbeActor::RebuildProbeRenderState()
{
	if (!ProbeMesh)
	{
		return;
	}

	UE_LOG(LogRenderPipelineProbe, Display,
		TEXT("Stage=RenderStateDirty Component=%s"),
		*ProbeMesh->GetName());
	ProbeMesh->MarkRenderStateDirty();
}

void ARenderPipelineProbeActor::DestroyProbeMesh()
{
	if (!ProbeMesh)
	{
		return;
	}

	UE_LOG(LogRenderPipelineProbe, Display,
		TEXT("Stage=Destroy Component=%s"), *ProbeMesh->GetName());
	ProbeMesh->DestroyComponent();
	ProbeMesh = nullptr;
}

void ARenderPipelineProbeActor::CreateProbeMesh()
{
	if (ProbeMesh)
	{
		return;
	}

	const FName NewComponentName = MakeUniqueObjectName(
		this,
		UStaticMeshComponent::StaticClass(),
		RenderPipelineProbe::MeshObjectName);
	ProbeMesh = NewObject<UStaticMeshComponent>(this, NewComponentName);
	ConfigureProbeMesh(*ProbeMesh);
	AddInstanceComponent(ProbeMesh);
	ProbeMesh->RegisterComponent();
	++ProbeGeneration;
	UE_LOG(LogRenderPipelineProbe, Display,
		TEXT("Stage=Create Component=%s Generation=%d"),
		*ProbeMesh->GetName(),
		ProbeGeneration);
}

void ARenderPipelineProbeActor::ConfigureProbeMesh(
	UStaticMeshComponent& MeshComponent)
{
	MeshComponent.SetupAttachment(SceneRoot);
	MeshComponent.SetStaticMesh(CubeAsset);
	MeshComponent.SetMaterial(0, SimpleMaterial);
	MeshComponent.SetCastShadow(false);
	MeshComponent.SetViewOwnerDepthPriorityGroup(true, SDPG_World);
	MeshComponent.ComponentTags.AddUnique(RenderPipelineProbe::MeshDebugTag);
	MeshComponent.SetRelativeLocation(RenderPipelineProbe::InitialLocation);
}
