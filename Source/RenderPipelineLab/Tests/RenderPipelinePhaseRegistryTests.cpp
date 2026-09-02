#if WITH_DEV_AUTOMATION_TESTS

#include "Misc/AutomationTest.h"
#include "Core/RenderPipelinePhaseRegistry.h"
#include "Phases/Phase0_StaticBox/Phase0StaticBoxActor.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FRenderPipelinePhaseRegistryTest,
	"Project.RenderPipelineLab.Registry.ResolvesKnownPhases",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FRenderPipelinePhaseRegistryTest::RunTest(const FString& Parameters)
{
	TestEqual(
		TEXT("Default Phase"),
		FRenderPipelinePhaseRegistry::GetDefaultPhaseId(),
		FName(TEXT("Phase0")));
	TestEqual(
		TEXT("Phase0 Class"),
		FRenderPipelinePhaseRegistry::Resolve(FName(TEXT("Phase0"))).Get(),
		APhase0StaticBoxActor::StaticClass());
	TestNull(
		TEXT("Unknown Phase"),
		FRenderPipelinePhaseRegistry::Resolve(FName(TEXT("Unknown"))).Get());
	return true;
}

#endif
