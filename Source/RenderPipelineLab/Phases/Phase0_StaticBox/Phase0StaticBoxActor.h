// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "Core/RenderPipelinePhaseActor.h"
#include "Phase0StaticBoxActor.generated.h"

class UCameraComponent;
class UDirectionalLightComponent;
class UMaterialInterface;
class USceneComponent;
class UStaticMesh;
class UStaticMeshComponent;

UCLASS()
class RENDERPIPELINELAB_API APhase0StaticBoxActor final
	: public ARenderPipelinePhaseActor
{
	GENERATED_BODY()

public:
	APhase0StaticBoxActor();

	virtual void BeginPlay() override;
	virtual FName GetPhaseId() const override
	{
		return FName(TEXT("Phase0"));
	}

	void ToggleProbeTransform();
	void RebuildProbeRenderState();
	void DestroyProbeMesh();
	void CreateProbeMesh();

	UStaticMeshComponent* GetProbeMesh() const { return ProbeMesh; }
	int32 GetProbeGeneration() const { return ProbeGeneration; }

private:
	void ConfigureProbeMesh(UStaticMeshComponent& MeshComponent);

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
};
