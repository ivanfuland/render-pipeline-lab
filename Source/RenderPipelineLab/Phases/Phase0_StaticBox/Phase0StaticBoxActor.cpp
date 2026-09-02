// Copyright Epic Games, Inc. All Rights Reserved.

#include "Phases/Phase0_StaticBox/Phase0StaticBoxActor.h"

#include "Camera/CameraComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/InputComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/PlayerController.h"
#include "InputCoreTypes.h"
#include "Kismet/GameplayStatics.h"
#include "Materials/MaterialInterface.h"
#include "RenderPipelineLab.h"
#include "UObject/ConstructorHelpers.h"

namespace RenderPipelineProbe
{
	const FName MeshObjectName(TEXT("RenderPipelineProbe_Box"));
	const FName MeshDebugTag(TEXT("RenderPipelineProbe.Box"));
	const FVector InitialLocation(0.0, 0.0, 0.0);
	const FVector OffsetLocation(0.0, 150.0, 0.0);
}

APhase0StaticBoxActor::APhase0StaticBoxActor()
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

void APhase0StaticBoxActor::BeginPlay()
{
	Super::BeginPlay();

	APlayerController* PlayerController =
		UGameplayStatics::GetPlayerController(this, 0);
	if (!PlayerController)
	{
		UE_LOG(LogRenderPipelineLab, Error,
			TEXT("Phase=Phase0 Stage=ReadyFailed Reason=NoPlayerController"));
		return;
	}

	PlayerController->SetViewTarget(this);
	EnableInput(PlayerController);
	if (!InputComponent)
	{
		UE_LOG(LogRenderPipelineLab, Error,
			TEXT("Phase=Phase0 Stage=ReadyFailed Reason=NoInputComponent"));
		return;
	}

	InputComponent->BindKey(EKeys::One, IE_Pressed, this,
		&APhase0StaticBoxActor::ToggleProbeTransform);
	InputComponent->BindKey(EKeys::Two, IE_Pressed, this,
		&APhase0StaticBoxActor::RebuildProbeRenderState);
	InputComponent->BindKey(EKeys::Three, IE_Pressed, this,
		&APhase0StaticBoxActor::DestroyProbeMesh);
	InputComponent->BindKey(EKeys::Four, IE_Pressed, this,
		&APhase0StaticBoxActor::CreateProbeMesh);

	UE_LOG(LogRenderPipelineLab, Display,
		TEXT("Phase=Phase0 Stage=Ready Component=%s"), *ProbeMesh->GetName());
	SchedulePixCaptureIfRequested();
}

void APhase0StaticBoxActor::ToggleProbeTransform()
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
	UE_LOG(LogRenderPipelineLab, Display,
		TEXT("Phase=Phase0 Stage=Transform Component=%s Offset=%d"),
		*ProbeMesh->GetName(),
		bProbeAtOffset ? 1 : 0);
}

void APhase0StaticBoxActor::RebuildProbeRenderState()
{
	if (!ProbeMesh)
	{
		return;
	}

	UE_LOG(LogRenderPipelineLab, Display,
		TEXT("Phase=Phase0 Stage=RenderStateDirty Component=%s"),
		*ProbeMesh->GetName());
	ProbeMesh->MarkRenderStateDirty();
}

void APhase0StaticBoxActor::DestroyProbeMesh()
{
	if (!ProbeMesh)
	{
		return;
	}

	UE_LOG(LogRenderPipelineLab, Display,
		TEXT("Phase=Phase0 Stage=Destroy Component=%s"), *ProbeMesh->GetName());
	ProbeMesh->DestroyComponent();
	ProbeMesh = nullptr;
}

void APhase0StaticBoxActor::CreateProbeMesh()
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
	UE_LOG(LogRenderPipelineLab, Display,
		TEXT("Phase=Phase0 Stage=Create Component=%s Generation=%d"),
		*ProbeMesh->GetName(),
		ProbeGeneration);
}

void APhase0StaticBoxActor::ConfigureProbeMesh(
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
