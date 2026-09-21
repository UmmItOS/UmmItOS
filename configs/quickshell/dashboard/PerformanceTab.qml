import QtQuick
import QtQuick.Layouts
import ".."

Item {
    RowLayout {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.spacing.extraLargeIncreased

        Gauge {
            Layout.alignment: Qt.AlignCenter
            value: SysInfo.gpuTemp / 100
            primary: Math.round(SysInfo.gpuTemp) + "°C"
            label: "GPU temp"
        }

        Gauge {
            Layout.alignment: Qt.AlignCenter
            value: SysInfo.cpuUsage
            primary: Math.round(SysInfo.cpuTemp) + "°C"
            label: Math.round(SysInfo.cpuUsage * 100) + "% CPU"
        }

        Gauge {
            Layout.alignment: Qt.AlignCenter
            value: SysInfo.memRatio
            primary: SysInfo.formatBytes(SysInfo.memUsed)
            label: "of " + SysInfo.formatBytes(SysInfo.memTotal)
        }

        Gauge {
            Layout.alignment: Qt.AlignCenter
            value: SysInfo.storageRatio
            primary: SysInfo.formatBytes(SysInfo.storageUsed)
            label: "of " + SysInfo.formatBytes(SysInfo.storageTotal)
        }
    }
}
