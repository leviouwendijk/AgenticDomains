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
///
/// Mailbox work goes through a local index of each account (the same files as
/// `email index`) and plans: `mail_index_sync`, `mail_clutter`,
/// `mail_suspicious`, `mail_decide` and `mail_plan` never change the server;
/// `mail_apply` and `mail_undo` do, with an organize grant and the owner's
/// approval of each plan. Three agents share that loop with different aims:
/// the Organizer (structure by content), the Cleaner (prune to `Pruned`) and
/// the Scanner (fraud and phishing).
@Domain
public enum Email {}
