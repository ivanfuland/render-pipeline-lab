// Copyright Epic Games, Inc. All Rights Reserved.

#include "Core/RenderPipelineLabGameMode.h"

#include "Core/RenderPipelinePhaseActor.h"
#include "Core/RenderPipelinePhaseRegistry.h"
#include "Core/RenderPipelineLabPlayerController.h"
#include "Engine/World.h"
#include "HAL/IConsoleManager.h"
#include "HAL/PlatformMisc.h"
#include "Misc/CommandLine.h"
#include "RenderPipelineLab.h"

ARenderPipelineLabGameMode::ARenderPipelineLabGameMode()
{
	DefaultPawnClass = nullptr;
	HUDClass = nullptr;
	PlayerControllerClass = ARenderPipelineLabPlayerController::StaticClass();
}

void ARenderPipelineLabGameMode::BeginPlay()
{
	Super::BeginPlay();
	LogRendererBaseline();

	FString PhaseValue;
	const bool bHasPhase = FParse::Value(
		FCommandLine::Get(),
		TEXT("RenderPipelinePhase="),
		PhaseValue);
	const FName PhaseId = bHasPhase
		? FName(*PhaseValue)
		: FRenderPipelinePhaseRegistry::GetDefaultPhaseId();

	const TSubclassOf<ARenderPipelinePhaseActor> PhaseClass =
		FRenderPipelinePhaseRegistry::Resolve(PhaseId);
	if (!PhaseClass)
	{
		UE_LOG(
			LogRenderPipelineLab,
			Error,
			TEXT("Stage=StartupFailed Reason=UnknownPhase Phase=%s"),
			*PhaseId.ToString());
		FPlatformMisc::RequestExitWithStatus(true, 2);
		return;
	}

	UWorld* World = GetWorld();
	if (!World)
	{
		UE_LOG(
			LogRenderPipelineLab,
			Error,
			TEXT("Stage=StartupFailed Reason=NoWorld Phase=%s"),
			*PhaseId.ToString());
		FPlatformMisc::RequestExitWithStatus(true, 4);
		return;
	}

	ARenderPipelinePhaseActor* PhaseActor =
		World->SpawnActor<ARenderPipelinePhaseActor>(
			PhaseClass,
			FVector::ZeroVector,
			FRotator::ZeroRotator);
	if (!PhaseActor)
	{
		UE_LOG(
			LogRenderPipelineLab,
			Error,
			TEXT("Stage=StartupFailed Reason=SpawnFailed Phase=%s"),
			*PhaseId.ToString());
		FPlatformMisc::RequestExitWithStatus(true, 5);
	}
}

void ARenderPipelineLabGameMode::LogRendererBaseline() const
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

	UE_LOG(LogRenderPipelineLab, Display, TEXT("RenderPipelineLab baseline"));
	for (const TCHAR* CVarName : CVarNames)
	{
		const IConsoleVariable* CVar =
			IConsoleManager::Get().FindConsoleVariable(CVarName);
		UE_LOG(
			LogRenderPipelineLab,
			Display,
			TEXT("BaselineCVar Name=%s Value=%s"),
			CVarName,
			CVar ? *CVar->GetString() : TEXT("Missing"));
	}
}
