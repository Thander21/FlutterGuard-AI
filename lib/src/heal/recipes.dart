// Production fast-path recipe table (SYS-REL-001 R4): rule id to
// mechanical HealRecipe for the HEAL-001 closed list. Humans run them
// through the thin `heal` CLI; anything unlisted stays agent-dispatched.
import 'dispatcher.dart';

/// Fast-path recipes keyed by rule id. Exactly the HEAL-001 closed
/// mechanical list: guard inserts (BLOC-001, ASYNC-002) and the
/// watch-to-read token swap (RIV-001).
const fastPathRecipes = <String, HealRecipe>{
  'FG-BLOC-001': HealRecipe.insert(
    ruleId: 'FG-BLOC-001',
    guard: 'if (isClosed) return;',
  ),
  'FG-RIV-001': HealRecipe.replace(
    ruleId: 'FG-RIV-001',
    from: 'ref.watch',
    to: 'ref.read',
  ),
  'FG-ASYNC-002': HealRecipe.insert(
    ruleId: 'FG-ASYNC-002',
    guard: 'if (!context.mounted) return;',
  ),
};

/// Returns the fast-path recipe for [ruleId], or null when the rule is
/// not mechanical (agent-dispatched).
HealRecipe? healRecipeFor(String ruleId) => fastPathRecipes[ruleId];
