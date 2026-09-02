// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "Core/RenderPipelinePhaseActor.h"
#include "Phase1DirectLightingActor.generated.h"

UCLASS()
class RENDERPIPELINELAB_API APhase1DirectLightingActor final
	: public ARenderPipelinePhaseActor
{
	GENERATED_BODY()

public:
	virtual FName GetPhaseId() const override
	{
		return FName(TEXT("Phase1"));
	}
};
