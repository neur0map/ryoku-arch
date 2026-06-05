import QtQuick

QtObject {
    required property string name
    property string icon: ""
    property string description: ""
    required property string endpoint
    required property string model
    required property string provider
    property bool requires_key: false
    property string key_id: ""
    property string key_get_link: ""
    property string key_get_description: ""
    property string api_format: ""
    property string customCurlTemplate: ""
}
