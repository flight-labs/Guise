/*
The MIT License (MIT)

Copyright (c) 2016 Gregory Higley (Prosumma)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import XCTest
@testable import Guise

class GuiseTests: XCTestCase {
    
    override class func setUp() {
        super.setUp()
        Guise.register{ ServerCommunicator(widgetCount: 3) as ServerCommunicating }
        Guise.register(name: "sc2") { () -> ServerCommunicating in
            let eight = Guise.resolve(name: "8")! as Int
            return ServerCommunicator(widgetCount: eight)
        }
        Guise.register(name: "sc3") { (count: Int) in ServerCommunicator(widgetCount: count) as ServerCommunicating }
        Guise.register(8, name: "8") // Any type can be registered
        let container = Guise.container("foo")
        container.register(lifecycle: .Once) { ServerCommunicator(widgetCount: 18) as ServerCommunicating }
    }
    
    func testResolveFooServerCommunicator() {
        let container = Guise.container("foo")
        let serverCommunicator = container.resolve()! as ServerCommunicating
        XCTAssertEqual(serverCommunicator.retrieveWidgetCount(), 18)
    }
    
    func testResolveServerCommunicator() {
        let serverCommunicator = Guise.resolve()! as ServerCommunicating
        XCTAssertEqual(serverCommunicator.retrieveWidgetCount(), 3)
    }
    
    func testResolveNamedServerCommunicator() {
        let serverCommunicator = Guise.resolve(name: "sc2")! as ServerCommunicating
        XCTAssertEqual(serverCommunicator.retrieveWidgetCount(), 8)
    }
    
    func testResolveParameterizedNamedServerCommunicator() {
        let count = 9
        let serverCommunicator = Guise.resolve(count, name: "sc3")! as ServerCommunicating
        XCTAssertEqual(serverCommunicator.retrieveWidgetCount(), count)
    }
    
    func testResolveInt() {
        let eight = Guise.resolve(name: "8")! as Int
        XCTAssertEqual(eight, 8)
    }
}
