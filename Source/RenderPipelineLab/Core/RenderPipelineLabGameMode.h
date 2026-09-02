// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "RenderPipelineLabGameMode.generated.h"

UCLASS()
class RENDERPIPELINELAB_API ARenderPipelineLabGameMode
	: public AGameModeBase
{
	GENERATED_BODY()

public:
	ARenderPipelineLabGameMode();

protected:
	virtual void BeginPlay() override;

private:
	void LogRendererBaseline() const;
};
