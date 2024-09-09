#ifndef SCREENWIDGET_H
#define SCREENWIDGET_H

#include <QObject>
#include <QWidget>
#include <QPainter>
#include <QImage>
#include <QEvent>
#include <QKeyEvent>
#include <QTimer>
#include <QDebug>

#include "memiocontroller.h"

class ScreenWidget : public QWidget
{
    Q_OBJECT

public:
    const static quint8 standard_colors[16][3];
    const static quint8 char_rom[128][8];

    explicit ScreenWidget(QWidget *parent = nullptr);
    ~ScreenWidget();
    void paintEvent(QPaintEvent *event);

public slots:
    void redrawTimeout();

private:
    QImage *m_scr = nullptr;
    QTimer *m_updater;
    bool m_flashing;
    int m_flash_countdown;
    const static int m_flash_rate = 15;

protected:
    void keyPressEvent(QKeyEvent *event);
};

#endif // SCREENWIDGET_H
