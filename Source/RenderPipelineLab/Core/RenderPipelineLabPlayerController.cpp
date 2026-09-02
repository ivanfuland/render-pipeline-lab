// Copyright Epic Games, Inc. All Rights Reserved.

#include "Core/RenderPipelineLabPlayerController.h"

#include "Kismet/GameplayStatics.h"
#include "RenderPipelineLab.h"

ARenderPipelineLabPlayerController::ARenderPipelineLabPlayerController()
{
	bShowMouseCursor = true;
}

void ARenderPipelineLabPlayerController::BeginPlay()
{
	Super::BeginPlay();

	SetShowMouseCursor(true);

	FInputModeGameAndUI InputMode;
	InputMode.SetHideCursorDuringCapture(false);
	InputMode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
	SetInputMode(InputMode);
	UGameplayStatics::SetViewportMouseCaptureMode(
		this,
		EMouseCaptureMode::NoCapture);

	UE_LOG(
		LogRenderPipelineLab,
		Display,
		TEXT("Input MouseCursor=Visible CaptureMode=NoCapture LockMode=DoNotLock"));
}
