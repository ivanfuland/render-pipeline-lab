// Copyright Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;

public class RenderPipelineLabTarget : TargetRules
{
	public RenderPipelineLabTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.V7;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_8;
		ExtraModuleNames.Add("RenderPipelineLab");
	}
}
