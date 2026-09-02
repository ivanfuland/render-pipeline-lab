// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RenderPipelinePhaseActor.generated.h"

UCLASS(Abstract)
class RENDERPIPELINELAB_API ARenderPipelinePhaseActor : public AActor
{
	GENERATED_BODY()

public:
	virtual FName GetPhaseId() const
		PURE_VIRTUAL(ARenderPipelinePhaseActor::GetPhaseId, return NAME_None;);

protected:
	void LogPhaseReady() const;
	void SchedulePixCaptureIfRequested();

private:
	void TriggerPixCapture();

	FTimerHandle PixCaptureTimer;
};
