// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"

class ARenderPipelinePhaseActor;

class RENDERPIPELINELAB_API FRenderPipelinePhaseRegistry
{
public:
	static FName GetDefaultPhaseId();
	static TSubclassOf<ARenderPipelinePhaseActor> Resolve(FName PhaseId);
};
