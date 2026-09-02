// Copyright Epic Games, Inc. All Rights Reserved.

#include "Core/RenderPipelinePhaseActor.h"

#include "Engine/Engine.h"
#include "Misc/CommandLine.h"
#include "RenderPipelineLab.h"
#include "TimerManager.h"

void ARenderPipelinePhaseActor::LogPhaseReady() const
{
	UE_LOG(
		LogRenderPipelineLab,
		Display,
		TEXT("Phase=%s Stage=Ready"),
		*GetPhaseId().ToString());
}

void ARenderPipelinePhaseActor::SchedulePixCaptureIfRequested()
{
	if (!FParse::Param(FCommandLine::Get(), TEXT("pixautocapture")))
	{
		return;
	}

	GetWorldTimerManager().SetTimer(
		PixCaptureTimer,
		this,
		&ARenderPipelinePhaseActor::TriggerPixCapture,
		5.0f,
		false);
}

void ARenderPipelinePhaseActor::TriggerPixCapture()
{
	UE_LOG(
		LogRenderPipelineLab,
		Display,
		TEXT("Phase=%s Stage=PixCaptureRequested Command=pix.GpuCaptureFrame"),
		*GetPhaseId().ToString());
	if (!GEngine->Exec(GetWorld(), TEXT("pix.GpuCaptureFrame")))
	{
		UE_LOG(
			LogRenderPipelineLab,
			Error,
			TEXT("Phase=%s Stage=PixCaptureFailed Reason=CommandUnavailable"),
			*GetPhaseId().ToString());
	}
}
