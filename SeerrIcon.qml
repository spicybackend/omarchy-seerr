import QtQuick
import qs.Commons

Item {
    id: root
    property color iconColor: Color.foreground

    Image {
        id: img
        anchors.centerIn: parent
        width: parent.width * 0.78
        height: parent.height * 0.78
        source: Qt.resolvedUrl("seerr-icon.svg")
        sourceSize.width: width
        sourceSize.height: height
        smooth: true
        visible: false
    }

    ShaderEffect {
        anchors.fill: img
        property variant src: img
        property color color: root.iconColor

        fragmentShader: "
            uniform lowp sampler2D src;
            uniform lowp vec4 color;
            varying highp vec2 qt_TexCoord0;
            void main() {
                lowp vec4 sample = texture2D(src, qt_TexCoord0);
                gl_FragColor = vec4(color.rgb, sample.a * color.a);
            }
        "
    }
}
