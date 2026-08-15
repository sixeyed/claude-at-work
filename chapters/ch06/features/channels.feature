@bdd
Feature: Channels

  Conversation in CollabHub happens in channels. A channel belongs to exactly one
  workspace — the one named in the signed-in user's token, never one named in a
  request — and a public channel is visible to everyone in that workspace whether
  or not they have joined it. Joining is what will gate reading messages, from a
  later slice; it does not gate seeing that a channel exists.

  The person who creates a channel administers it. Nothing here exercises that
  yet: renaming, archiving and membership are the next slice.

  Real-time delivery is a later slice too, so a second person sees a new channel
  the next time their app loads. The scenario below says that out loud rather
  than quietly reloading and implying the update arrived on its own.

  Background:
    Given Ada is signed in

  @smoke
  Scenario: Ada signs in and sees her workspace
    # Proves the whole harness end to end before any channel exists: the stack is
    # up, the real Dex sign-in worked, and the SPA rendered what Auth returned.
    Then Ada sees the "CollabHub Demo" workspace

  Scenario: Ada creates a public channel and lands in it
    When Ada creates a public channel named "general"
    Then Ada is looking at the "general" channel
    And "general" is in Ada's channel list

  Scenario: A new public channel appears for another member
    Given Ada has created a public channel named "general"
    When Grace opens CollabHub
    Then "general" is in Grace's channel list

  Scenario: A public channel name cannot be reused
    Given Ada has created a public channel named "general"
    When Ada tries to create a second public channel named "general"
    Then Ada is told that channel name is already taken
    And "general" appears in Ada's channel list exactly once

  Scenario: A channel name cannot be blank
    When Ada tries to create a public channel with a blank name
    Then Ada is told a channel name is required
    And Ada's channel list is empty