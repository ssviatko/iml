#include "memiocontroller.h"

MemIOController::MemIOController(QObject *parent) : QObject(parent)
  , m_video_dirty(false)
{

}

MemIOController& MemIOController::get()
{
    static MemIOController shared_instance;
    return shared_instance;
}

void MemIOController::init()
{
    m_mem = new quint8[MEMSIZE];
    if (m_mem == nullptr) {
        qWarning() << "No memory available for main memory array.";
    }
    for (quint32 i = 0; i < MEMSIZE; ++i)
        m_mem[i] = 0;
}

void MemIOController::teardown()
{
    if (m_mem != nullptr)
        delete[] m_mem;
}

bool MemIOController::isVideoDirty()
{
    return m_video_dirty;
}

void MemIOController::clearVideoDirty()
{
    m_video_dirty = false;
}

void MemIOController::setVideoDirty()
{
    m_video_dirty = true;
}

quint8 MemIOController::read(quint32 a_address)
{
    // check if we're reading over the top of memory
    if (a_address >= MEMSIZE)
        return 0xff;

    // check if IO shadowing is on, and adjust address accordingly
    if (m_mem[IOSTART + SHADOW_IO] > 127) {
        if ((a_address >= IOSHADOWSTART) && (a_address <= IOSHADOWEND)) {
            a_address += (IOSTART - IOSHADOWSTART);
            // and then fall thru..
        }
    }

    // check if E4 shadowing is on, and adjust address accordingly
    if (m_mem[IOSTART + SHADOW_E4] > 127) {
        if ((a_address >= E400ROMSTART) && (a_address <= E400ROMEND)) {
            a_address += (E4SHADOWSTART - E400ROMSTART);
            // and then fall thru..
        }
    }

    quint8 l_iob;
    quint32 l_shadowbase;

    // check 67 shadowing
    l_iob = m_mem[IOSTART + SHADOW_67];
    l_shadowbase = l_iob << 13;
    if (l_iob > 7) {
        if ((a_address >= 0x6000) && (a_address <= 0x7fff)) {
            a_address = l_shadowbase + (a_address - 0x6000);
        }
    }

    // check 89 shadowing
    l_iob = m_mem[IOSTART + SHADOW_89];
    l_shadowbase = l_iob << 13;
    if (l_iob > 7) {
        if ((a_address >= 0x8000) && (a_address <= 0x9fff)) {
            a_address = l_shadowbase + (a_address - 0x8000);
        }
    }

    // check AB shadowing
    l_iob = m_mem[IOSTART + SHADOW_AB];
    l_shadowbase = l_iob << 13;
    if (l_iob > 7) {
        if ((a_address >= 0xa000) && (a_address <= 0xbfff)) {
            a_address = l_shadowbase + (a_address - 0xa000);
        }
    }

    // check CD shadowing
    l_iob = m_mem[IOSTART + SHADOW_CD];
    l_shadowbase = l_iob << 13;
    if (l_iob > 7) {
        if ((a_address >= 0xc000) && (a_address <= 0xdfff)) {
            a_address = l_shadowbase + (a_address - 0xc000);
        }
    }

    // deal with KEYQ_WAITING
    if (a_address == IOSTART + KEYQ_WAITING)
        return hc_key_waiting();

    // deal with KEYQ_SIZE
    if (a_address == IOSTART + KEYQ_SIZE)
        return hc_keyq_size();

    return m_mem[a_address];
}

void MemIOController::write(quint32 a_address, quint8 a_value)
{
    // check if we're writing over the top of memory
    if (a_address >= MEMSIZE)
        return;

    // check if IO shadowing is on, and adjust address accordingly
    if (m_mem[IOSTART + SHADOW_IO] > 127) {
        if ((a_address >= IOSHADOWSTART) && (a_address <= IOSHADOWEND)) {
            a_address += (IOSTART - IOSHADOWSTART);
            // and then fall thru..
        }
    }

    // check if E4 shadowing is on, and adjust address accordingly
    if (m_mem[IOSTART + SHADOW_E4] > 127) {
        if ((a_address >= E400ROMSTART) && (a_address <= E400ROMEND)) {
            a_address += (E4SHADOWSTART - E400ROMSTART);
            // and then fall thru..
        }
    }

    quint8 l_iob;
    quint32 l_shadowbase;

    // check 67 shadowing
    l_iob = m_mem[IOSTART + SHADOW_67];
    l_shadowbase = l_iob << 13;
    if (l_iob > 7) {
        if ((a_address >= 0x6000) && (a_address <= 0x7fff)) {
            a_address = l_shadowbase + (a_address - 0x6000);
        }
    }

    // check 89 shadowing
    l_iob = m_mem[IOSTART + SHADOW_89];
    l_shadowbase = l_iob << 13;
    if (l_iob > 7) {
        if ((a_address >= 0x8000) && (a_address <= 0x9fff)) {
            a_address = l_shadowbase + (a_address - 0x8000);
        }
    }

    // check AB shadowing
    l_iob = m_mem[IOSTART + SHADOW_AB];
    l_shadowbase = l_iob << 13;
    if (l_iob > 7) {
        if ((a_address >= 0xa000) && (a_address <= 0xbfff)) {
            a_address = l_shadowbase + (a_address - 0xa000);
        }
    }

    // check CD shadowing
    l_iob = m_mem[IOSTART + SHADOW_CD];
    l_shadowbase = l_iob << 13;
    if (l_iob > 7) {
        if ((a_address >= 0xc000) && (a_address <= 0xdfff)) {
            a_address = l_shadowbase + (a_address - 0xc000);
        }
    }

    // check our write protected ROM ranges
    if ((a_address >= ZEROPAGESTART) && (a_address <= ZEROPAGEEND)) {
        if (m_mem[IOSTART + WP_ZEROPAGE] > 127)
            return;
    }
    if ((a_address >= E400ROMSTART) && (a_address <= E400ROMEND)) {
        if (m_mem[IOSTART + WP_E400_ROM] > 127)
            return;
    }
    if ((a_address >= X1CROMSTART) && (a_address <= X1CROMEND)) {
        if (m_mem[IOSTART + WP_X1C_ROM] > 127)
            return;
    }

    // check if we're writing to video memory
    if ((a_address >= VIDSTART) && (a_address <= VIDEND))
        m_video_dirty = true;

    // check if we're modifying VID_MODE
    if (a_address == IOSTART + VID_MODE)
        m_video_dirty = true;

    // deal with KEYQ_DEQUEUE
    if (a_address == IOSTART + KEYQ_DEQUEUE)
        hc_dequeue();

    // deal with KEYQ_CLEAR
    if (a_address == IOSTART + KEYQ_CLEAR)
        hc_keyq_clear();

    // deal with CON_CLS
    if (a_address == IOSTART + CON_CLS)
        hc_con_cls();

    // deal with CON_REGISTER
    if (a_address == IOSTART + CON_REGISTER)
        hc_con_register();

    // deal with CON_CURSOR
    if (a_address == IOSTART + CON_CURSOR) {
        quint8 l_existing_cursor = m_mem[a_address];
        if ((l_existing_cursor < 128) && (a_value > 127))
            hc_con_showcursor();
        else if ((l_existing_cursor > 127) && (a_value < 128))
            hc_con_hidecursor();
        m_mem[a_address] = a_value;
        m_video_dirty = true;
        return;
    }

    if ((a_address == IOSTART + CON_CURSORH) || (a_address == IOSTART + CON_CURSORV)) {
        hc_con_hidecursor();
        m_mem[a_address] = a_value;
        hc_con_showcursor();
        m_video_dirty = true;
        return;
    }

    if (a_address == IOSTART + CON_CR)
        hc_con_cr();

    m_mem[a_address] = a_value;
}

// hard console implementation

void MemIOController::hc_register_keypress(char a_kp)
{
    QMutexLocker l_locker(&m_keyq_mutex);
    m_keyq.enqueue(a_kp);
}

int MemIOController::hc_keyq_size()
{
    return m_keyq.size();
}

char MemIOController::hc_key_waiting()
{
    QMutexLocker l_locker(&m_keyq_mutex);
    if (m_keyq.isEmpty())
        return 0x80;
    else
        return m_keyq.head();
}

void MemIOController::hc_dequeue()
{
    QMutexLocker l_locker(&m_keyq_mutex);
    if (!m_keyq.isEmpty())
        m_keyq.dequeue();
}

void MemIOController::hc_keyq_clear()
{
    QMutexLocker l_locker(&m_keyq_mutex);
    m_keyq.clear();
}

void MemIOController::hc_con_cls()
{
    QMutexLocker l_locker(&m_con_mutex);
    quint8 l_w, l_h;
    if (m_mem[IOSTART + VID_MODE] == 0x08) {
        l_w = 40;
        l_h = 17;
    } else if (m_mem[IOSTART + VID_MODE] == 0x09) {
        l_w = 80;
        l_h = 34;
    } else {
        // not in either of the text modes, so do nothing
        return;
    }
    quint8 l_cursoron = m_mem[IOSTART + CON_CURSOR];
    if (l_cursoron > 127) {
        hc_con_hidecursor();
        m_mem[IOSTART + CON_CURSOR] = 0x00;
    }
    for (unsigned int h = 0; h < l_h; ++h) {
        for (unsigned int w = 0; w < l_w; ++w) {
            m_mem[VIDSTART + (h * l_w * 2) + (w * 2)] = m_mem[IOSTART + CON_CHAROUT];
            m_mem[VIDSTART + (h * l_w * 2) + (w * 2) + 1] = m_mem[IOSTART + CON_COLOR];
        }
    }
    m_mem[IOSTART + CON_CURSORH] = 0;
    m_mem[IOSTART + CON_CURSORV] = 0;
    if (l_cursoron > 127) {
        hc_con_showcursor();
        m_mem[IOSTART + CON_CURSOR] = 0x80;
    }
    m_video_dirty = true;
}

void MemIOController::hc_con_register()
{
//    qDebug() << "hc_con_register";
    quint8 l_w, l_h;
    if (m_mem[IOSTART + VID_MODE] == 0x08) {
        l_w = 40;
        l_h = 17;
    } else if (m_mem[IOSTART + VID_MODE] == 0x09) {
        l_w = 80;
        l_h = 34;
    } else {
        // not in either of the text modes, so do nothing
        return;
    }
    quint8 l_cursoron = m_mem[IOSTART + CON_CURSOR];
    if (l_cursoron > 127) {
        hc_con_hidecursor();
        m_mem[IOSTART + CON_CURSOR] = 0x00;
    }
    quint32 l_base = VIDSTART + (m_mem[IOSTART + CON_CURSORH] * 2) + (l_w * m_mem[IOSTART + CON_CURSORV] * 2);
    m_mem[l_base] = m_mem[IOSTART + CON_CHAROUT];
    m_mem[l_base + 1] = m_mem[IOSTART + CON_COLOR];
    // advance the cursor
    m_mem[IOSTART + CON_CURSORH] += 1;
    if (m_mem[IOSTART + CON_CURSORH] >= l_w) {
        m_mem[IOSTART + CON_CURSORH] = 0;
        m_mem[IOSTART + CON_CURSORV] += 1;
        if (m_mem[IOSTART + CON_CURSORV] >= l_h) {
            m_mem[IOSTART + CON_CURSORV] = l_h - 1;
//            qDebug() << "scrolling...";
            // scroll the screen
            for (quint32 d = VIDSTART; d < VIDSTART + (l_w * 2) * (l_h - 1); ++d) {
                m_mem[d] = m_mem[d + (l_w * 2)];
            }
//            qDebug() << "blanking...";
            // blank out the last line
            for (quint32 d = VIDSTART + (l_w * 2) * (l_h - 1); d < VIDSTART + (l_w * 2) * l_h; d += 2) {
                m_mem[d] = 0x20;
                m_mem[d + 1] = m_mem[IOSTART + CON_COLOR];
            }
        }
    }
    if (l_cursoron > 127) {
        hc_con_showcursor();
        m_mem[IOSTART + CON_CURSOR] = 0x80;
    }
    m_video_dirty = true;
}

void MemIOController::hc_con_cr()
{
    quint8 l_w, l_h;
    if (m_mem[IOSTART + VID_MODE] == 0x08) {
        l_w = 40;
        l_h = 17;
    } else if (m_mem[IOSTART + VID_MODE] == 0x09) {
        l_w = 80;
        l_h = 34;
    } else {
        // not in either of the text modes, so do nothing
        return;
    }
    quint8 l_cursoron = m_mem[IOSTART + CON_CURSOR];
    if (l_cursoron > 127) {
        hc_con_hidecursor();
        m_mem[IOSTART + CON_CURSOR] = 0x00;
    }
    m_mem[IOSTART + CON_CURSORH] = 0;
    m_mem[IOSTART + CON_CURSORV] += 1;
    if (m_mem[IOSTART + CON_CURSORV] >= l_h) {
        m_mem[IOSTART + CON_CURSORV] = l_h - 1;
//            qDebug() << "scrolling...";
        // scroll the screen
        for (quint32 d = VIDSTART; d < VIDSTART + (l_w * 2) * (l_h - 1); ++d) {
            m_mem[d] = m_mem[d + (l_w * 2)];
        }
//            qDebug() << "blanking...";
        // blank out the last line
        for (quint32 d = VIDSTART + (l_w * 2) * (l_h - 1); d < VIDSTART + (l_w * 2) * l_h; d += 2) {
            m_mem[d] = 0x20;
            m_mem[d + 1] = m_mem[IOSTART + CON_COLOR];
        }
    }
    if (l_cursoron > 127) {
        hc_con_showcursor();
        m_mem[IOSTART + CON_CURSOR] = 0x80;
    }
    m_video_dirty = true;
}

void MemIOController::hc_con_togglecursor()
{
    quint8 l_w;
    if (m_mem[IOSTART + VID_MODE] == 0x08) {
        l_w = 40;
    } else if (m_mem[IOSTART + VID_MODE] == 0x09) {
        l_w = 80;
    } else {
        // not in either of the text modes, so do nothing
        return;
    }
    quint32 l_base = VIDSTART + (m_mem[IOSTART + CON_CURSORH] * 2) + (l_w * m_mem[IOSTART + CON_CURSORV] * 2);
    quint8 l_color_flipped = m_mem[l_base + 1];
    quint8 l_low = (l_color_flipped & 0xf) << 4;
    quint8 l_high = (l_color_flipped & 0xf0) >> 4;
    l_color_flipped = l_high | l_low;
    m_mem[l_base + 1] = l_color_flipped;
}

void MemIOController::hc_con_showcursor()
{
    if (m_mem[IOSTART + CON_CURSOR] > 127)
        return;
    hc_con_togglecursor();
}

void MemIOController::hc_con_hidecursor()
{
    if (m_mem[IOSTART + CON_CURSOR] < 128)
        return;
    hc_con_togglecursor();
}
