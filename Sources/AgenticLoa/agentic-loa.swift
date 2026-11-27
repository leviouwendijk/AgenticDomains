import Agentic

/// Loa in Agentic: the model writes a Loa program instead of a series of tool calls.
/// `loa_program_run` runs it, calling the installed tools through the Program context (so
/// preflight, approval and recovery are the dispatcher's, unchanged), `loa_program_check`
/// checks it without running, and `loa_program_reference` gives the catalog the program
/// may call.
@Domain("loa")
public enum LoaLang {}
