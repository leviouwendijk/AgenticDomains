import Agentic

/// Mail over the accounts in `~/.config/mail/*.frame` (the Mail library's own
/// configuration, shared with the `email` command line): list mailboxes,
/// search and read without marking anything seen, save drafts, and send
/// within each account's `sending` policy.
///
/// Nothing needs to be inserted: the default store is used unless the
/// session's services hold an `Email.Runtime` or a `MailConfigurationStore`.
/// Passwords never reach a tool's input or output.
@Domain
public enum Email {}
