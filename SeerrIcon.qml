import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Commons

Item {
    id: root
    property color iconColor: Color.foreground

    Image {
        id: img
        anchors.centerIn: parent
        width: parent.width * 0.78
        height: parent.height * 0.78
        source: Qt.resolvedUrl("icon.svg")
        sourceSize.width: width
        sourceSize.height: height
        smooth: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: img
        source: img
        color: root.iconColor
    }
}
