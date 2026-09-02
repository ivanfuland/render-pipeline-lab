// Copyright Epic Games, Inc. All Rights Reserved.

#include "RenderPipelineProbeGameMode.h"

#include "RenderPipelineProbeActor.h"
#include "Engine/World.h"
#include "HAL/IConsoleManager.h"

ARenderPipelineProbeGameMode::ARenderPipelineProbeGameMode()
{
	DefaultPawnClass = nullptr;
	HUDClass = nullptr;
}

void ARenderPipelineProbeGameMode::BeginPlay()
{
	Super::BeginPlay();

	LogRendererBaseline();
	if (UWorld* World = GetWorld())
	{
		World->SpawnActor<ARenderPipelineProbeActor>(
			ARenderPipelineProbeActor::StaticClass(),
			FVector::ZeroVector,
			FRotator::ZeroRotator);
	}
}

void ARenderPipelineProbeGameMode::LogRendererBaseline() const
{
	static const TCHAR* CVarNames[] = {
		TEXT("r.ForwardShading"),
		TEXT("r.Nanite.ProjectEnabled"),
		TEXT("r.DynamicGlobalIlluminationMethod"),
		TEXT("r.ReflectionMethod"),
		TEXT("r.RayTracing"),
		TEXT("r.Substrate"),
		TEXT("r.Shadow.Virtual.Enable")
	};

	UE_LOG(LogRenderPipelineProbe, Display,
		TEXT("RenderPipelineProbe baseline"));
	for (const TCHAR* CVarName : CVarNames)
	{
		const IConsoleVariable* CVar =
			IConsoleManager::Get().FindConsoleVariable(CVarName);
		UE_LOG(LogRenderPipelineProbe, Display,
			TEXT("BaselineCVar Name=%s Value=%s"),
			CVarName,
			CVar ? *CVar->GetString() : TEXT("Missing"));
	}
}
