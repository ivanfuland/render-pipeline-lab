#if WITH_DEV_AUTOMATION_TESTS

#include "Misc/AutomationTest.h"
#include "Phases/Phase0_StaticBox/Phase0StaticBoxActor.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/World.h"
#include "Materials/MaterialInterface.h"
#include "UObject/GarbageCollection.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FPhase0StaticBoxActorLifecycleTest,
	"Project.RenderPipelineLab.Phase0.ActorLifecycle",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FPhase0StaticBoxActorLifecycleTest::RunTest(const FString& Parameters)
{
	UWorld* TestWorld = UWorld::CreateWorld(
		EWorldType::Game,
		false,
		FName(TEXT("RenderPipelineProbeTestWorld")));
	TestNotNull(TEXT("Transient test world exists"), TestWorld);
	if (!TestWorld)
	{
		return false;
	}
	TestWorld->AddToRoot();

	APhase0StaticBoxActor* Probe =
		TestWorld->SpawnActor<APhase0StaticBoxActor>();
	TestNotNull(TEXT("Probe actor spawned"), Probe);
	if (!Probe)
	{
		TestWorld->RemoveFromRoot();
		TestWorld->DestroyWorld(false);
		return false;
	}
	TestEqual(TEXT("Phase ID"), Probe->GetPhaseId(), FName(TEXT("Phase0")));
	TestNotNull(TEXT("Probe mesh exists"), Probe->GetProbeMesh());
	TestTrue(
		TEXT("Probe enables the dynamic mesh draw gate"),
		Probe->GetProbeMesh()->bUseViewOwnerDepthPriorityGroup);
	TestTrue(
		TEXT("Probe mesh has stable debug tag"),
		Probe->GetProbeMesh()->ComponentHasTag(
			FName(TEXT("RenderPipelineProbe.Box"))));
	TestEqual(
		TEXT("Probe uses the texture-free BasicShape material"),
		Probe->GetProbeMesh()->GetMaterial(0)->GetPathName(),
		FString(TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial")));

	const FVector InitialLocation = Probe->GetProbeMesh()->GetRelativeLocation();
	Probe->ToggleProbeTransform();
	TestNotEqual(
		TEXT("First transform action moves the mesh"),
		Probe->GetProbeMesh()->GetRelativeLocation(),
		InitialLocation);
	Probe->ToggleProbeTransform();
	TestEqual(
		TEXT("Second transform action restores the mesh"),
		Probe->GetProbeMesh()->GetRelativeLocation(),
		InitialLocation);

	const int32 InitialGeneration = Probe->GetProbeGeneration();
	Probe->DestroyProbeMesh();
	TestNull(TEXT("Destroy clears the mesh pointer"), Probe->GetProbeMesh());
	Probe->CreateProbeMesh();
	TestNotNull(TEXT("Create restores the mesh"), Probe->GetProbeMesh());
	TestEqual(
		TEXT("Create increments generation"),
		Probe->GetProbeGeneration(),
		InitialGeneration + 1);
	CollectGarbage(GARBAGE_COLLECTION_KEEPFLAGS);
	TestTrue(
		TEXT("Recreated mesh remains valid after garbage collection"),
		IsValid(Probe->GetProbeMesh()));
	TestTrue(
		TEXT("Recreated mesh remains registered after garbage collection"),
		Probe->GetProbeMesh() && Probe->GetProbeMesh()->IsRegistered());

	TestWorld->RemoveFromRoot();
	TestWorld->DestroyWorld(false);
	return true;
}

#endif
