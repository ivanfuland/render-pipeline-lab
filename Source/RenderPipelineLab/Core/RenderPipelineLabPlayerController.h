// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "RenderPipelineLabPlayerController.generated.h"

UCLASS()
class RENDERPIPELINELAB_API ARenderPipelineLabPlayerController
	: public APlayerController
{
	GENERATED_BODY()

public:
	ARenderPipelineLabPlayerController();

protected:
	virtual void BeginPlay() override;
};
