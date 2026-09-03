#if WITH_DEV_AUTOMATION_TESTS

#include "Misc/AutomationTest.h"
#include "Phases/Phase1_DirectLighting/Phase1DirectLightingActor.h"

#include "Camera/CameraComponent.h"
#include "Components/SpotLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FPhase1DirectLightingContractTest,
	"Project.RenderPipelineLab.Phase1.ComponentContract",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FPhase1DirectLightingContractTest::RunTest(const FString& Parameters)
{
	UWorld* World = UWorld::CreateWorld(
		EWorldType::Game,
		false,
		FName(TEXT("Phase1ContractTestWorld")));
	TestNotNull(TEXT("World"), World);
	if (!World)
	{
		return false;
	}
	World->AddToRoot();

	APhase1DirectLightingActor* Actor =
		World->SpawnActor<APhase1DirectLightingActor>();
	TestNotNull(TEXT("Actor"), Actor);
	if (!Actor)
	{
		World->RemoveFromRoot();
		World->DestroyWorld(false);
		return false;
	}

	TestNotNull(TEXT("Box"), Actor->GetBoxCaster());
	TestNotNull(TEXT("Plane"), Actor->GetPlaneReceiver());
	TestNotNull(TEXT("Spot"), Actor->GetSpotLight());
	TestNotNull(TEXT("Camera"), Actor->GetCamera());
	TestTrue(TEXT("Box casts"), Actor->GetBoxCaster()->CastShadow);
	TestFalse(TEXT("Plane does not cast"), Actor->GetPlaneReceiver()->CastShadow);
	TestEqual(
		TEXT("Box mobility"),
		Actor->GetBoxCaster()->GetMobility(),
		EComponentMobility::Static);
	TestEqual(
		TEXT("Plane mobility"),
		Actor->GetPlaneReceiver()->GetMobility(),
		EComponentMobility::Static);
	TestEqual(
		TEXT("Spot mobility"),
		Actor->GetSpotLight()->GetMobility(),
		EComponentMobility::Movable);
	TestEqual(
		TEXT("Spot source radius"),
		Actor->GetSpotLight()->SourceRadius,
		0.0f);
	TestEqual(
		TEXT("Spot source length"),
		Actor->GetSpotLight()->SourceLength,
		0.0f);
	TestEqual(
		TEXT("Spot contact shadow"),
		Actor->GetSpotLight()->ContactShadowLength,
		0.0f);
	TestEqual(
		TEXT("Spot intensity avoids clipping the teaching scene"),
		Actor->GetSpotLight()->Intensity,
		300.0f);
	TestNull(TEXT("Spot IES"), Actor->GetSpotLight()->IESTexture.Get());
	TestNull(
		TEXT("Spot light function"),
		Actor->GetSpotLight()->LightFunctionMaterial.Get());
	TestFalse(
		TEXT("Spot disallows MegaLights"),
		Actor->GetSpotLight()->bAllowMegaLights);
	TestTrue(
		TEXT("Default lighting channel"),
		Actor->GetSpotLight()->LightingChannels.bChannel0);
	TestFalse(
		TEXT("Lighting channel 1 disabled"),
		Actor->GetSpotLight()->LightingChannels.bChannel1);
	TestFalse(
		TEXT("Lighting channel 2 disabled"),
		Actor->GetSpotLight()->LightingChannels.bChannel2);
	TestEqual(TEXT("Phase ID"), Actor->GetPhaseId(), FName(TEXT("Phase1")));

	const FBoxSphereBounds BoxBounds =
		Actor->GetBoxCaster()->GetStaticMesh()->GetBounds();
	const FVector BoxLocation = Actor->GetBoxCaster()->GetRelativeLocation();
	const FVector BoxScale = Actor->GetBoxCaster()->GetRelativeScale3D();
	const FVector FrontFaceCenter = BoxLocation + FVector(
		0.0,
		-BoxBounds.BoxExtent.Y * BoxScale.Y,
		0.0);
	const FVector SurfaceToLight =
		Actor->GetSpotLight()->GetRelativeLocation() - FrontFaceCenter;
	const float CameraFacingNoL = FVector::DotProduct(
		FVector(0.0, -1.0, 0.0),
		SurfaceToLight.GetSafeNormal());
	TestTrue(
		TEXT("Camera-facing Box face receives direct light"),
		CameraFacingNoL > 0.25f);

	const float BoxMaxX =
		BoxLocation.X + BoxBounds.BoxExtent.X * BoxScale.X;
	TestTrue(
		TEXT("Receiver target extends beyond the Box footprint"),
		APhase1DirectLightingActor::GetReceiverTargetWorldPosition().X > BoxMaxX);

	const FVector BoxTopCenter = BoxLocation + FVector(
		0.0,
		0.0,
		BoxBounds.BoxExtent.Z * BoxScale.Z);
	const FVector LightLocation = Actor->GetSpotLight()->GetRelativeLocation();
	const FVector ReceiverTarget =
		APhase1DirectLightingActor::GetReceiverTargetWorldPosition();
	const double ProjectionAlpha =
		(ReceiverTarget.Z - LightLocation.Z) /
		(BoxTopCenter.Z - LightLocation.Z);
	const FVector ProjectedTopCenter = LightLocation +
		ProjectionAlpha * (BoxTopCenter - LightLocation);
	TestTrue(
		TEXT("Receiver target stays near the projected Box shadow center"),
		FVector2D::Distance(
			FVector2D(ReceiverTarget.X, ReceiverTarget.Y),
			FVector2D(ProjectedTopCenter.X, ProjectedTopCenter.Y)) < 15.0);

	World->RemoveFromRoot();
	World->DestroyWorld(false);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FPhase1ShadowModeParseTest,
	"Project.RenderPipelineLab.Phase1.ShadowModeParsing",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FPhase1ShadowModeParseTest::RunTest(const FString& Parameters)
{
	const auto DefaultMode =
		APhase1DirectLightingActor::ParseShadowMode(TEXT(""));
	const auto On =
		APhase1DirectLightingActor::ParseShadowMode(TEXT("-Phase1Shadow=On"));
	const auto Off =
		APhase1DirectLightingActor::ParseShadowMode(TEXT("-Phase1Shadow=Off"));
	const auto Invalid =
		APhase1DirectLightingActor::ParseShadowMode(TEXT("-Phase1Shadow=Invalid"));

	TestTrue(
		TEXT("Default is On"),
		DefaultMode.IsSet() && DefaultMode.GetValue() == EPhase1ShadowMode::On);
	TestTrue(
		TEXT("On parsed"),
		On.IsSet() && On.GetValue() == EPhase1ShadowMode::On);
	TestTrue(
		TEXT("Off parsed"),
		Off.IsSet() && Off.GetValue() == EPhase1ShadowMode::Off);
	TestFalse(TEXT("Invalid rejected"), Invalid.IsSet());
	return true;
}

#endif
