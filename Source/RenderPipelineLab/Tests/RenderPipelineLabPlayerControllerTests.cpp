#if WITH_DEV_AUTOMATION_TESTS

#include "Misc/AutomationTest.h"
#include "Core/RenderPipelineLabGameMode.h"
#include "Core/RenderPipelineLabPlayerController.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FRenderPipelineLabMouseCursorContractTest,
	"Project.RenderPipelineLab.Input.MouseCursorContract",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FRenderPipelineLabMouseCursorContractTest::RunTest(
	const FString& Parameters)
{
	const ARenderPipelineLabGameMode* GameMode =
		GetDefault<ARenderPipelineLabGameMode>();
	TestEqual(
		TEXT("Lab player controller class"),
		GameMode->PlayerControllerClass.Get(),
		ARenderPipelineLabPlayerController::StaticClass());

	const ARenderPipelineLabPlayerController* PlayerController =
		GetDefault<ARenderPipelineLabPlayerController>();
	TestTrue(
		TEXT("Lab player controller shows the mouse cursor"),
		PlayerController->bShowMouseCursor);
	return true;
}

#endif
