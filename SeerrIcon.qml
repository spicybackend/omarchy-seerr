import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
    id: root
    property color iconColor: Color.foreground

    readonly property real iconScale: 0.82
    transform: [
        Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: (root.width / 96) * root.iconScale
            yScale: (root.height / 96) * root.iconScale
        },
        Translate { y: -root.height * 0.08 }
    ]

    Shape {
        width: 96
        height: 96
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: root.iconColor
            fillRule: ShapePath.OddEvenFill
            PathSvg {
                path: "M48 96C74.5097 96 96 74.5097 96 48C96 21.4903 74.5097 0 48 0C21.4903 0 0 21.4903 0 48C0 74.5097 21.4903 96 48 96ZM80.0001 52C80.0001 67.464 67.4641 80 52.0001 80C36.5361 80 24.0001 67.464 24.0001 52C24.0001 49.1303 24.4318 46.3615 25.2338 43.7548C27.4288 48.6165 32.3194 52 38.0001 52C45.7321 52 52.0001 45.732 52.0001 38C52.0001 32.3192 48.6166 27.4287 43.755 25.2337C46.3616 24.4317 49.1304 24 52.0001 24C67.4641 24 80.0001 36.536 80.0001 52Z"
            }
        }
    }

    Shape {
        width: 96
        height: 96
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.6

        ShapePath {
            strokeWidth: 0
            fillColor: root.iconColor
            fillRule: ShapePath.OddEvenFill
            PathSvg {
                path: "M48 12C28.1177 12 12 28.1177 12 48C12 50.2091 10.2091 52 8 52C5.79086 52 4 50.2091 4 48C4 23.6995 23.6995 4 48 4C50.2091 4 52 5.79086 52 8C52 10.2091 50.2091 12 48 12Z"
            }
        }
    }
}
