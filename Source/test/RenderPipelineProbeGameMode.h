// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "RenderPipelineProbeGameMode.generated.h"

UCLASS()
class TEST_API ARenderPipelineProbeGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	ARenderPipelineProbeGameMode();

protected:
	virtual void BeginPlay() override;

private:
	void LogRendererBaseline() const;
};
