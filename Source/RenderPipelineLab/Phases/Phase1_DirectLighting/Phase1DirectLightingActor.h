// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "Core/RenderPipelinePhaseActor.h"
#include "Phase1DirectLightingActor.generated.h"

class UCameraComponent;
class USceneComponent;
class USpotLightComponent;
class UStaticMeshComponent;

UENUM()
enum class EPhase1ShadowMode : uint8
{
	On,
	Off
};

UCLASS()
class RENDERPIPELINELAB_API APhase1DirectLightingActor final
	: public ARenderPipelinePhaseActor
{
	GENERATED_BODY()

public:
	APhase1DirectLightingActor();

	virtual void BeginPlay() override;
	virtual FName GetPhaseId() const override
	{
		return FName(TEXT("Phase1"));
	}

	static TOptional<EPhase1ShadowMode> ParseShadowMode(
		const TCHAR* CommandLine);
	static FVector GetReceiverTargetWorldPosition();

	UStaticMeshComponent* GetBoxCaster() const { return BoxCaster; }
	UStaticMeshComponent* GetPlaneReceiver() const { return PlaneReceiver; }
	USpotLightComponent* GetSpotLight() const { return SpotLight; }
	UCameraComponent* GetCamera() const { return Camera; }

private:
	void ValidateAndLogReady();
	bool ValidateBaselineAndLog() const;

	UPROPERTY()
	TObjectPtr<USceneComponent> SceneRoot;

	UPROPERTY()
	TObjectPtr<UStaticMeshComponent> BoxCaster;

	UPROPERTY()
	TObjectPtr<UStaticMeshComponent> PlaneReceiver;

	UPROPERTY()
	TObjectPtr<USpotLightComponent> SpotLight;

	UPROPERTY()
	TObjectPtr<UCameraComponent> Camera;

	EPhase1ShadowMode ShadowMode = EPhase1ShadowMode::On;
	FTimerHandle ReadyTimer;
};
