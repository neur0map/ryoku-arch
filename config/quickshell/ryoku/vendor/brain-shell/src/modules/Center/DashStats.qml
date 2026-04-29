import QtQuick
import "../../"
import "../../components"
import "../../services/"

Item {
    id: root

    CpuService         { id: cpu;     active: root.visible }
    MemService         { id: mem;     active: root.visible }
    NetService         { id: net;     active: root.visible }
    ThermalService     { id: thermal; active: root.visible }
    FanControl         { id: fan }
    DiskService        { id: disk;    active: root.visible }
    EnvyControlService { id: envy }
    CpuFreqService     { id: cpuFreq }
    GpuService {
        id:       gpu
        active:   root.visible
        envyMode: envy.currentMode
    }

    Column {
        anchors {
            fill:          parent
            bottomMargin:  8
            topMargin:     8
        }
        spacing: 8

        // Speedometers
        Row {
            id:      speedoRow
            width:   parent.width
            anchors.topMargin: 4
            height:  160
            spacing: 8

            StatCard {
                width:  (parent.width - parent.spacing * 3) / 4
                height: parent.height
                Speedometer {
                    anchors.centerIn: parent
                    label:       "CPU"
                    percent:     cpu.usagePercent
                    centerText:  cpu.usagePercent + "%"
                    bottomText:  cpuFreq.curFreqStr
                    active:      true
                    accentColor: Theme.active
                }
            }

            StatCard {
                width:  (parent.width - parent.spacing * 3) / 4
                height: parent.height
                Speedometer {
                    anchors.centerIn: parent
                    label:       "RAM"
                    percent:     mem.usagePercent
                    centerText:  mem.usagePercent + "%"
                    bottomText:  mem.usedStr + " / " + mem.totalStr
                    active:      true
                    accentColor: "#cba6f7"
                }
            }

            StatCard {
                width:  (parent.width - parent.spacing * 3) / 4
                height: parent.height
                Speedometer {
                    anchors.centerIn: parent
                    label:       "iGPU"
                    percent:     gpu.igpu.freqPercent
                    centerText:  gpu.igpu.freqPercent + "%"
                    bottomText:  gpu.igpu.curMhz
                    active:      true
                    accentColor: "#89dceb"
                }
            }

            StatCard {
                width:  (parent.width - parent.spacing * 3) / 4
                height: parent.height
                Speedometer {
                    anchors.centerIn: parent
                    label:       "dGPU"
                    percent:     gpu.dgpu.active ? gpu.dgpu.usagePercent : 0
                    centerText:  gpu.dgpu.active ? (gpu.dgpu.usagePercent + "%") : "0%"
                    bottomText:  gpu.dgpu.active ? (gpu.dgpu.usedVram + " / " + gpu.dgpu.totalVram) : ""
                    active:      gpu.dgpu.active
                    accentColor: "#a6e3a1"
                }
            }
        }
        
        Row{
            width:   parent.width
            height:  100
            spacing: 8
            // Thermal strip
            StatCard {
                width:   (parent.width-parent.spacing)/2
                height:  parent.height
                padding: 6
    
                TempPanel {
                    anchors.fill: parent
                    service:      thermal
                    dgpuActive:   gpu.dgpu.active
                }
            }
            
            // Fan control strip
            StatCard {
                width:   (parent.width-parent.spacing)/2
                height:  parent.height
                padding: 6
                
                FanPanel {
                    anchors.fill: parent
                    service:      fan
                }
            }
        }
        // Net | Disk | Power
        Row {
            width:   parent.width
            height:  parent.height - speedoRow.height - 100 - parent.spacing 
            spacing: 8

            // Network — narrow, only 3 rows
            StatCard {
                width:  Math.round(parent.width * 0.20)
                height: parent.height
                NetStatsPanel {
                    anchors.fill: parent
                    service:      net
                }
            }

            // Disks — moderate, horizontal bars stack vertically
            StatCard {
                width:  Math.round(parent.width * 0.35)
                height: parent.height
                DiskPanel {
                    anchors.fill: parent
                    service:      disk
                }
            }

            // Power — widest, two button rows need space
            StatCard {
                width:  parent.width - Math.round(parent.width * 0.20) - Math.round(parent.width * 0.35) - parent.spacing * 2
                height: parent.height
                PowerPanel {
                    anchors.fill:   parent
                    cpuFreqService: cpuFreq
                    envyService:    envy
                }
            }
        }
    }
}
