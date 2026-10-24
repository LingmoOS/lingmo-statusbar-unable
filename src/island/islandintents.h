#pragma once

class QObject;

// Lingmo Intents on com.lingmo.Island /Intents: island.start, island.update
// and island.finish. They go through the Island's own D-Bus methods (the same
// path as any app), always as persistent activities (the caller of an intent
// is usually gone before the activity ends), and update/finish only touch
// activities started through these intents.
void publishIslandIntents(QObject *parent);
