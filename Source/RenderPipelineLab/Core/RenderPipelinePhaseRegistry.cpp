// Copyright Epic Games, Inc. All Rights Reserved.

#include "Core/RenderPipelinePhaseRegistry.h"

#include "Phases/Phase0_StaticBox/Phase0StaticBoxActor.h"
#include "Phases/Phase1_DirectLighting/Phase1DirectLightingActor.h"

FName FRenderPipelinePhaseRegistry::GetDefaultPhaseId()
{
	return FName(TEXT("Phase0"));
}

TSubclassOf<ARenderPipelinePhaseActor> FRenderPipelinePhaseRegistry::Resolve(
	FName PhaseId)
{
	if (PhaseId == FName(TEXT("Phase0")))
	{
		return APhase0StaticBoxActor::StaticClass();
	}
	if (PhaseId == FName(TEXT("Phase1")))
	{
		return APhase1DirectLightingActor::StaticClass();
	}
	return nullptr;
}
