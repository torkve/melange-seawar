import QtQuick 2.0
import QtQuick.Controls 1.0
import QtQuick.Layouts 1.0

ApplicationWindow {
    width: 600
    height: 600
    color: "#ffffff"

    Column {
        id: column1
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 15
        height: parent.height

        Text {
            id: statusText
            text: qsTr("Wait...")
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenterOffset: 0
            anchors.topMargin: 15
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 24
        }

        Row {
            id: row1
            //anchors.bottom: parent.bottom
            //anchors.top: statusText.bottom
            spacing: 20
            width: column1.width
            height: column1.height - statusText.height - column1.spacing

            GridView {
                id: ownField
                width: Math.min((parent.width - parent.spacing) / 2, parent.height)
                height: Math.min((parent.width - parent.spacing) / 2, parent.height)
                model: ownBoardModel

                cellWidth: width / 10
                cellHeight: height / 10

                interactive: false
                delegate: Rectangle {
                    width: ownField.cellWidth
                    height: ownField.cellHeight
                    border.color: "#000000"
                    border.width: 1
                    Text {
                        text: cell.cellState
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: parent.height
                        font.pixelSize: height * 0.7
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            GridView {
                id: opponentField
                width: Math.min((parent.width - parent.spacing) / 2, parent.height)
                height: Math.min((parent.width - parent.spacing) / 2, parent.height)
                model: oppBoardModel

                cellWidth: width / 10
                cellHeight: height / 10

                interactive: false

                property bool ownTurn: true

                delegate: Rectangle {
                    width: opponentField.cellWidth
                    height: opponentField.cellHeight
                    border.color: "#000000"
                    border.width: 1
                    Text {
                        text: cell.cellState
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: parent.height
                        font.pixelSize: height * 0.7
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: if(opponentField.ownTurn){opponentField.model.onMouseClicked(cellX, cellY)}
                    }
                }
            }
        }
        Text {
            text: qsTr("kekeke...")
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenterOffset: 0
            anchors.bottomMargin: 15
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 24
        }
    }

    Connections {
        target: game
        onNoteChanged: statusText.text = qsTr(newNote)
        onTurnChanged: opponentField.ownTurn = (nextTurn == "own")
    }
    Component.onCompleted: game.initBaseState()
}
