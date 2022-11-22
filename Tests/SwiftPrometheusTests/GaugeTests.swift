import XCTest
import NIO
@testable import Prometheus
@testable import CoreMetrics

final class GaugeTests: XCTestCase {
    let baseLabels = DimensionLabels([("myValue", "labels")])
    var prom: PrometheusClient!
    var group: EventLoopGroup!
    var eventLoop: EventLoop {
        return group.next()
    }
    
    override func setUp() {
        self.prom = PrometheusClient()
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        MetricsSystem.bootstrapInternal(PrometheusMetricsFactory(client: prom))
    }
    
    override func tearDown() {
        self.prom = nil
        try! self.group.syncShutdownGracefully()
    }
    
    func testGaugeSwiftMetrics() async {
        let gauge = Gauge(label: "my_gauge")
        
        gauge.record(10)
        gauge.record(12)
        gauge.record(20)
        
        let gaugeTwo = Gauge(label: "my_gauge_with_dimensions", dimensions: [("myValue", "labels")])
        gaugeTwo.record(10)

        let metrics: String = await prom.collect()
        
        XCTAssertEqual(metrics, """
        # TYPE my_gauge gauge
        my_gauge 20.0
        # TYPE my_gauge_with_dimensions gauge
        my_gauge_with_dimensions{myValue=\"labels\"} 10.0\n
        """)
    }

    func testGaugeTime() {
        let gauge = prom.createGauge(forType: Double.self, named: "my_gauge")
        let delay = 0.05
        gauge.time {
            Thread.sleep(forTimeInterval: delay)
        }
        // Using starts(with:) here since the exact subseconds might differ per-test.
        XCTAssert(gauge.collect().starts(with: """
        # TYPE my_gauge gauge
        my_gauge \(isCITestRun ? "" : "0.05")
        """))
    }

    func testGaugeStandalone() {
        let gauge = prom.createGauge(forType: Int.self, named: "my_gauge", helpText: "Gauge for testing", initialValue: 10)
        XCTAssertEqual(gauge.get(), 10)
        gauge.inc(10)
        XCTAssertEqual(gauge.get(), 20)
        gauge.dec(12)
        XCTAssertEqual(gauge.get(), 8)
        gauge.set(20)
        //gauge.inc(10, baseLabels)
        XCTAssertEqual(gauge.get(), 20)
        //XCTAssertEqual(gauge.get(baseLabels), 20)

        //let gaugeTwo = prom.createGauge(forType: Int.self, named: "my_gauge_2", helpText: "Gauge for testing", initialValue: 10)
        //XCTAssertEqual(gaugeTwo.get(), 10)
        //gaugeTwo.inc()
        //XCTAssertEqual(gaugeTwo.get(), 11)
        
        XCTAssertEqual(gauge.collect(), """
        # HELP my_gauge Gauge for testing
        # TYPE my_gauge gauge
        my_gauge 20
        """)
    }
}
