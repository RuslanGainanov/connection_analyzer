#include "widget.h"
#include "ui_widget.h"

Widget::Widget(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::Widget)
{
    ui->setupUi(this);
    last_start_time=0;
    nwam = new QNetworkAccessManager;
    connect(nwam, SIGNAL(finished(QNetworkReply*)), this, SLOT(replyFinish(QNetworkReply*)));

    ui->comboBoxUserName->addItems(UserName);
    ui->comboBoxHostName->addItems(HostAndMac.keys());
    ui->lineEditMac->setText(HostAndMac.first());
}

Widget::~Widget()
{
    delete ui;
}


void Widget::replyFinish(QNetworkReply *reply)
{
    QString answer = QString::fromUtf8(reply->readAll());
    Q_UNUSED(answer)
//    qDebug() << "answer" << answer << reply->error();
}

void Widget::on_pushButtonCreate_clicked()
{
    QUrlQuery query;
    query.addQueryItem("precision","s");
    query.addQueryItem("db","itgrp");
    query.addQueryItem("u","itgrp_user");
    query.addQueryItem("p","8NAbgv1MBQ7abA");

    QString  apiUrl = "http://10.8.0.1:8086/write";
    QUrl url(apiUrl);
    url.setQuery(query);

    QNetworkRequest request;
    request.setUrl(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("application/x-www-form-urlencoded"));
    request.setRawHeader("Content-Transfer-Encoding","binary");

    QDateTime dt = ui->dateTimeEdit->dateTime().toUTC();
    uint time = dt.toTime_t();
    bool start = ui->radioButtonS->isChecked();
    QDateTime d;
    d.setOffsetFromUtc(0);
    d.setDate(QDate(dt.date()));
    d.setTime(QTime());
    uint start_date_time = d.toTime_t();
    QString requestString =
            QString("connections,Event=%1,UserName=%2,UserMac=%3,NasName=%4,HostName=%5,Ip=%6 z_D=%7i,z_SF=%8i,z_IP=\"%9\" %10")
            .arg(start? "0": "3")
            .arg(ui->comboBoxUserName->currentText())
            .arg(ui->lineEditMac->text())
            .arg(ui->lineEditNasName->text())
            .arg(ui->comboBoxHostName->currentText())
            .arg(ui->lineEditIp->text())
            .arg(start? QString::number(time - start_date_time): QString::number(time - last_start_time))
            .arg(start? "0": "1")
            .arg(start? ui->lineEditIp->text(): "-")
            .arg(time);
    qDebug() << requestString+"000000000";
    last_start_time = start? time : 0;
    nwam->post( request,
                QString(requestString).toUtf8());
}
void Widget::on_comboBoxHostName_currentIndexChanged(const QString &arg1)
{
    ui->lineEditMac->setText(HostAndMac.value(arg1,""));
}

