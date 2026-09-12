#include "visualizer.h"

#include <QByteArrayList>

CavaVisualizer::CavaVisualizer(QObject *parent)
    : QObject(parent)
{
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &CavaVisualizer::readOutput);
    connect(&m_process, &QProcess::stateChanged, this, [this](QProcess::ProcessState state) {
        const bool isRunning = state != QProcess::NotRunning;
        if (isRunning != running()) {
            Q_EMIT runningChanged();
        }
    });
}

QVariantList CavaVisualizer::values() const
{
    return m_values;
}

bool CavaVisualizer::running() const
{
    return m_process.state() != QProcess::NotRunning;
}

void CavaVisualizer::stop()
{
    if (m_process.state() != QProcess::NotRunning) {
        m_process.terminate();
        if (!m_process.waitForFinished(250)) {
            m_process.kill();
        }
    }
    m_buffer.clear();
    if (!m_values.isEmpty()) {
        m_values.clear();
        Q_EMIT valuesChanged();
    }
}

void CavaVisualizer::configure(bool enabled, int barCount)
{
    barCount = qBound(8, barCount, 64);
    if (!enabled) {
        stop();
        return;
    }

    if (m_process.state() != QProcess::NotRunning && barCount == m_barCount) {
        return;
    }

    stop();
    m_barCount = barCount;

    const QByteArray config = QByteArrayLiteral("[general]\n")
        + "bars = " + QByteArray::number(m_barCount) + "\n"
        + "framerate = 30\n"
        + "[output]\n"
        + "method = raw\n"
        + "raw_target = /dev/stdout\n"
        + "data_format = ascii\n"
        + "ascii_max_range = 100\n"
        + "bar_delim = 59\n"
        + "frame_delim = 10\n";

    m_process.start(QStringLiteral("cava"), {QStringLiteral("-p"), QStringLiteral("/dev/stdin")});
    if (!m_process.waitForStarted(500)) {
        return;
    }
    m_process.write(config);
    m_process.closeWriteChannel();
}

void CavaVisualizer::readOutput()
{
    m_buffer += m_process.readAllStandardOutput();
    while (true) {
        const qsizetype end = m_buffer.indexOf('\n');
        if (end < 0) {
            break;
        }

        const QByteArray line = m_buffer.left(end).trimmed();
        m_buffer.remove(0, end + 1);
        const QList<QByteArray> parts = line.split(';');
        if (parts.size() < 1) {
            continue;
        }

        QVariantList next;
        next.reserve(parts.size());
        for (const QByteArray &part : parts) {
            bool ok = false;
            const int level = part.toInt(&ok);
            if (ok) {
                next.append(qBound(0, level, 100) / 100.0);
            }
        }
        if (!next.isEmpty()) {
            m_values = next;
            Q_EMIT valuesChanged();
        }
    }
}
