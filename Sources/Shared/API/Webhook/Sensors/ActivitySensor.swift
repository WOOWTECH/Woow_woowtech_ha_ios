import CoreMotion
import Foundation
import PromiseKit

// MARK: - First-release policy boundary (fitness sensors)

//
// Owner decision 2026-09-13: the first release declares NO health/fitness functionality on
// Google Play, so the sensors that collect fitness data are stopped rather than declared.
// This covers step count, walking distance, floors ascended/descended and motion activity type.
//
// Preserved verbatim behind a compilation condition that is intentionally NOT defined in any
// xcconfig, so it is excluded from every build product. Re-enabling is an explicit, greppable
// act: define WOOWTECH_ENABLE_FITNESS_SENSORS and re-open the Play health declaration and the
// ASC privacy questionnaire fitness category.
//
// WebhookSensorId cases are deliberately retained for legacy identifier/data compatibility.
// No sensor history is deleted; the sensors simply stop being reported.
#if WOOWTECH_ENABLE_FITNESS_SENSORS
public class ActivitySensor: SensorProvider {
    public enum ActivityError: Error {
        case unauthorized
        case unavailable
        case noData
    }

    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        firstly {
            Self.latestMotionActivity()
        }.map { activity in
            with(WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)) {
                $0.State = activity.activityTypes.first
                $0.Attributes = [
                    "Confidence": activity.confidence.description,
                    "Types": activity.activityTypes,
                ]
                $0.Icon = activity.icons.first
            }
        }.map {
            [$0]
        }
    }

    private static func latestMotionActivity() -> Promise<CMMotionActivity> {
        guard Current.motion.isAuthorized() else {
            return .init(error: ActivityError.unauthorized)
        }

        guard Current.motion.isActivityAvailable() else {
            Current.Log.warning("Activity is not available")
            return .init(error: ActivityError.unavailable)
        }

        let (promise, seal) = Promise<CMMotionActivity>.pending()
        let end = Current.date()
        let start = Current.calendar().date(byAdding: .minute, value: -10, to: end)!
        let queue = OperationQueue.main
        Current.motion.queryStartEndOnQueueHandler(start, end, queue) { activities, error in
            if let latestActivity = activities?.last {
                seal.fulfill(latestActivity)
            } else if let error {
                seal.reject(error)
            } else {
                seal.reject(ActivityError.noData)
            }
        }
        return promise
    }
}
#endif
