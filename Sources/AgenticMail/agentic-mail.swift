import Agentic

/// Mail over the accounts in every root's `.config/mail/*.frame`: your own
/// `~/.config/mail`, then the shared roots in `~/.config/roots.frame` (the
/// Mail library's own configuration, shared with the `email` command line
/// and, through a shared root, with the team): list mailboxes,
/// search and read without marking anything seen, save drafts, and send
/// within each account's `sending` policy.
///
/// Nothing needs to be inserted: the default store is used unless the
/// session's services hold an `Email.Runtime` or a `MailConfigurationStore`.
/// Passwords never reach a tool's input or output.
@Domain
public enum Email {}
