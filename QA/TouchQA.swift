import XCTest
final class TouchQA: XCTestCase {
    func testTouchScenes() {
        XCUIDevice.shared.orientation = .landscapeLeft
        for game in ["garden","spa","aquarium","potionlab"] {
            let app=XCUIApplication()
            app.launchArguments=["-game",game]
            app.launch()
            sleep(2)
            let scale=min(app.frame.width/1024,app.frame.height/834)
            func point(_ x:CGFloat,_ y:CGFloat)->XCUICoordinate {
                app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:app.frame.width/2+(x-512)*scale,dy:app.frame.height/2+(y-417)*scale))
            }
            func swipe(_ x:CGFloat,_ y:CGFloat,_ xx:CGFloat,_ yy:CGFloat) {
                point(x,y).press(forDuration:0.18,thenDragTo:point(xx,yy))
            }
            func capture(_ name:String) {
                let photo=XCTAttachment(screenshot:app.screenshot())
                photo.name=name; photo.lifetime = .keepAlways
                add(photo)
            }
            capture(game+"-opening")
            switch game {
            case "garden":
                let zoom=min(1.22,(app.frame.width/scale-20)/950)
                swipe(512+(235-512)*zoom,834+(580-818)*zoom,512+(289-512)*zoom,834+(622-818)*zoom)
            case "spa":
                swipe(401,321,322,189); swipe(574,331,650,197)
            case "aquarium":
                let z=min((app.frame.width/scale-16)/964,(710-88)/(704-(AGeoProxy.rim-30)))
                swipe(512+(630-512)*z,710+(600-704)*z,512+(465-512)*z,710+(510-704)*z)
            default:
                point(68,204).tap(); point(166,204).tap()
                swipe(204,479,328,533); point(686,653).tap()
            }
            sleep(2)
            XCTAssertEqual(app.state,.runningForeground)
            capture(game+"-play")
            app.terminate()
        }
    }
}
private enum AGeoProxy { static let rim:CGFloat = 164 }
