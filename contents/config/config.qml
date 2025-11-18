// content/config/config.qml
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")  //Name given to the tab in config
        icon: "configure"  //self-explanatory
        source: "configGeneral.qml"  //path inside ui folder
    }                                //which would represent
}                                    //the layout of this config page
