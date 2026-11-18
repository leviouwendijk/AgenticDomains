import Agentic

/// Mail over the accounts in `domains/mail.frame`: list mailboxes, search and
/// read without marking anything seen, save drafts, and send within each
/// account's `sending` policy.
///
/// Accounts, servers, identities and password references are supplied by the
/// application through `Email.ConfigurationStore` (or a `Email.Runtime`) in
/// the session's tool services. Passwords never reach a tool's input or output.
@Domain
public enum Email {}
