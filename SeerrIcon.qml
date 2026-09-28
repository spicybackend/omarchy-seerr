import QtQuick
import qs.Commons

Item {
    id: root
    property color iconColor: Color.foreground

    Canvas {
        id: canvas
        anchors.centerIn: parent
        width: parent.width * 0.78
        height: parent.height * 0.78

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (img.status !== Image.Ready) return
            ctx.drawImage(img, 0, 0, width, height)
            ctx.globalCompositeOperation = "source-in"
            ctx.fillStyle = root.iconColor
            ctx.fillRect(0, 0, width, height)
        }

        Image {
            id: img
            source: Qt.resolvedUrl("seerr-icon.svg")
            sourceSize.width: parent.width
            sourceSize.height: parent.height
            smooth: true
            visible: false
            onStatusChanged: if (status === Image.Ready) canvas.requestPaint()
        }

        onIconColorChanged: requestPaint()
    }
}
