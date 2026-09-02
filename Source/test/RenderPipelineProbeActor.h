// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RenderPipelineProbeActor.generated.h"

class UCameraComponent;
class UDirectionalLightComponent;
class UMaterialInterface;
class USceneComponent;
class UStaticMesh;
class UStaticMeshComponent;

DECLARE_LOG_CATEGORY_EXTERN(LogRenderPipelineProbe, Log, All);

UCLASS()
class TEST_API ARenderPipelineProbeActor : public AActor
{
	GENERATED_BODY()

public:
	ARenderPipelineProbeActor();

	virtual void BeginPlay() override;

	void ToggleProbeTransform();
	void RebuildProbeRenderState();
	void DestroyProbeMesh();
	void CreateProbeMesh();

	UStaticMeshComponent* GetProbeMesh() const { return ProbeMesh; }
	int32 GetProbeGeneration() const { return ProbeGeneration; }

private:
	void ConfigureProbeMesh(UStaticMeshComponent& MeshComponent);
	void TriggerPixCapture();

	UPROPERTY()
	TObjectPtr<USceneComponent> SceneRoot;

	UPROPERTY()
	TObjectPtr<UStaticMeshComponent> ProbeMesh;

	UPROPERTY()
	TObjectPtr<UStaticMesh> CubeAsset;

	UPROPERTY()
	TObjectPtr<UMaterialInterface> SimpleMaterial;

	UPROPERTY()
	TObjectPtr<UCameraComponent> Camera;

	UPROPERTY()
	TObjectPtr<UDirectionalLightComponent> DirectionalLight;

	int32 ProbeGeneration = 1;
	bool bProbeAtOffset = false;
	FTimerHandle PixCaptureTimer;
};
