part of '../settings_page.dart';

bool _notificationsVisible(WidgetRef ref) {
  if (defaultTargetPlatform != TargetPlatform.iOS) return false;
  final community = ref.watch(activeCommunityProvider).value;
  if (community == null) return false;
  final setup = ref.watch(buzzPushSetupStatusProvider);
  final capability = ref.watch(currentRelayPushDescriptorProvider);
  return (!capability.isLoading &&
          !capability.hasError &&
          capability.value != null) ||
      community.pushNotificationsEnabled ||
      community.pushSubscriptionState.pendingTombstoneGeneration != null ||
      setup.hasError;
}

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_notificationsVisible(ref)) return const SizedBox.shrink();
    final community = ref.watch(activeCommunityProvider).value!;
    final setup = ref.watch(buzzPushSetupStatusProvider);
    final capability = ref.watch(currentRelayPushDescriptorProvider);
    final hasCapability =
        !capability.isLoading &&
        !capability.hasError &&
        capability.value != null;

    final pendingOff =
        !community.pushNotificationsEnabled &&
        community.pushSubscriptionState.pendingTombstoneGeneration != null;
    final turningOff =
        pendingOff &&
        ref.watch(pushOptOutAttemptsProvider).contains(community.id);
    // A failed opt-out shows the last confirmed setting: the relay may still
    // hold the lease, so notifications may continue.
    final optOutFailed = pendingOff && !turningOff;
    final shownEnabled = community.pushNotificationsEnabled || optOutFailed;
    final canToggle = hasCapability || shownEnabled;
    final communities = ref.read(communityListProvider.notifier);

    void retryOptOut() => unawaited(communities.retryPushOptOut(community.id));

    void keepOn() =>
        unawaited(communities.setPushNotificationsEnabled(community.id, true));

    void setEnabled(bool enabled) {
      if (optOutFailed) return retryOptOut();
      unawaited(communities.setPushNotificationsEnabled(community.id, enabled));
    }

    return AppListCard(
      verticalPadding: Grid.twelve,
      children: [
        if (setup.hasError)
          AppListRow(
            key: const ValueKey('push-setup-retry'),
            title: 'Notification setup failed',
            subtitle: 'You can keep using Buzz. Tap to retry notifications.',
            onTap: () => retryBuzzPushSetup(ref),
          ),
        MergeSemantics(
          key: const ValueKey('push-notifications-setting'),
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              AppListRow(
                key: const ValueKey('push-notifications-enabled'),
                title: 'Notifications',
                // Until the relay confirms, off is not yet true.
                subtitle: turningOff ? 'Turning off…' : null,
                // Reserve horizontal room without letting the switch's 48dp
                // layout height expand the row.
                trailing: const SizedBox(width: 60),
                onTap: canToggle ? () => setEnabled(!shownEnabled) : null,
              ),
              Positioned.fill(
                right: Grid.xs,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Switch.adaptive(
                    value: shownEnabled,
                    onChanged: canToggle ? setEnabled : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (optOutFailed)
          Column(
            key: const ValueKey('push-opt-out-failed'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppListRow(
                title: "Couldn't turn off notifications",
                titleColor: context.colors.error,
                subtitle: 'They may continue.',
              ),
              // Below the text, not trailing it, so large text sizes wrap
              // the actions instead of covering the warning.
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppListInset.of(context) - Grid.xs,
                ),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    TextButton(onPressed: keepOn, child: const Text('Keep on')),
                    TextButton(
                      onPressed: retryOptOut,
                      child: const Text(
                        'Retry',
                        semanticsLabel: 'Retry turning off notifications',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
