#ifndef MEMIOCONTROLLER_H
#define MEMIOCONTROLLER_H

#include <QObject>
#include <QException>
#include <QQueue>
#include <QDebug>
#include <QMutex>
#include <QMutexLocker>

#define MEMSIZE     0x200000

class MemIOController : public QObject
{
    Q_OBJECT
    explicit MemIOController(QObject *parent = nullptr);

public:
    // video space
    const static quint32 VIDSTART = 0x180000;
    const static quint32 VIDEND = 0x1bfbff;

    // reserved memory spaces
    const static quint32 ZEROPAGESTART = 0x000000;
    const static quint32 ZEROPAGEEND = 0x0000ff;
    const static quint32 E400ROMSTART = 0x00e400;
    const static quint32 E400ROMEND = 0x00ffff;
    const static quint32 X1CROMSTART = 0x1c0000;
    const static quint32 X1CROMEND = 0x1fffff;

    // IO space
    const static quint32 IOSTART = 0x1bfc00;
    const static quint32 IOEND = 0x1bffff;
    const static quint32 IOSHADOWSTART = 0x00e000;
    const static quint32 IOSHADOWEND = 0x00e3ff;
    const static quint32 E4SHADOWSTART = 0x1fe400;
    const static quint32 E4SHADOWEND = 0x1fffff;

    // IO offsets into IO space
    const static quint32 KEYQ_SIZE = 0x00;
    const static quint32 KEYQ_WAITING = 0x01;
    const static quint32 KEYQ_DEQUEUE = 0x02;
    const static quint32 KEYQ_CLEAR = 0x03;
    const static quint32 CON_CLS = 0x10;
    const static quint32 CON_COLOR = 0x11;
    const static quint32 CON_CHAROUT = 0x12;
    const static quint32 CON_REGISTER = 0x13;
    const static quint32 CON_CURSORH = 0x14;
    const static quint32 CON_CURSORV = 0x15;
    const static quint32 CON_CURSOR = 0x16;
    const static quint32 CON_CR = 0x17;
    const static quint32 VID_MODE = 0x20;
    const static quint32 WP_ZEROPAGE = 0x28;
    const static quint32 WP_E400_ROM = 0x29;
    const static quint32 WP_X1C_ROM = 0x2a;
    const static quint32 SHADOW_IO = 0x30;
    const static quint32 SHADOW_E4 = 0x31;
    const static quint32 SHADOW_67 = 0x38;
    const static quint32 SHADOW_89 = 0x39;
    const static quint32 SHADOW_AB = 0x3a;
    const static quint32 SHADOW_CD = 0x3b;

    static MemIOController& get();
    void init();
    void teardown();
    bool isVideoDirty();
    void clearVideoDirty();
    void setVideoDirty();
    quint8 read(quint32 a_address);
    void write(quint32 a_address, quint8 a_value);

    // Hard console internal api
    void hc_register_keypress(char a_kp); // insert keypress into key queue
    int hc_keyq_size(); // return key queue size
    char hc_key_waiting(); // next key waiting in the key queue, or else 0x80
    void hc_dequeue(); // remove the head keypress from key queue
    void hc_keyq_clear(); // empty the key queue
    void hc_con_cls(); // clear current text screen to CON_CHAROUT, with CON_COLOR for colors.
    void hc_con_register(); // print CON_CHAROUT at current cursor position, with CON_COLOR for colors.
    void hc_con_cr(); // effect a carriage return

protected:
    quint8 *m_mem = nullptr;
    bool m_video_dirty;

    QQueue<char> m_keyq;
    QMutex m_keyq_mutex;
    QMutex m_con_mutex;
    void hc_con_showcursor(); // show the cursor at current cursor position
    void hc_con_hidecursor(); // hide the cursor at current cursor position
    void hc_con_togglecursor();

signals:

};

#endif // MEMIOCONTROLLER_H
