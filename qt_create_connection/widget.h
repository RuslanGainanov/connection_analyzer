#ifndef WIDGET_H
#define WIDGET_H

#include <QWidget>
#include <QMap>
#include <QString>
#include <QDebug>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrlQuery>
#include <QProcess>

namespace Ui {
class Widget;
}

const QMap< QString, QString > HostAndMac {
    {"Zavialov-PC", "00-FF-00-FF-00-FF"},
    {"Kulagin-PC",  "01-23-45-67-89-AB"},
    {"Ivanov-PC", "AB-CD-ED-01-23-45"}
};

const QList< QString > NasName {
    "DWS-3024", "DWS-2430"
};

const QList< QString > UserName{
    "IT-GRP\\avzavialov",
    "IT-GRP\\evkulagin",
    "IT-GRP\\ymivanov"
};

class Widget : public QWidget
{
    Q_OBJECT

public:
    explicit Widget(QWidget *parent = 0);
    ~Widget();

private slots:
    void on_pushButtonCreate_clicked();
    void on_comboBoxHostName_currentIndexChanged(const QString &arg1);
    void replyFinish(QNetworkReply *reply);

private:
    Ui::Widget *ui;
    QNetworkAccessManager *nwam;
    QProcess *p;
    uint last_start_time;
};

#endif // WIDGET_H
