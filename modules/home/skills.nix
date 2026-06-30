{ ... }:

let
  # Agents only scan one level of the skills dir, so nested IDs (modularity/foo)
  # aren't discovered. Flatten under a modularity- prefix instead, rewriting the
  # frontmatter name to match (skill names can't contain ':' like plugins do).
  modularitySkill = leaf: {
    from = "modularity";
    path = leaf;
    transform =
      { original, ... }:
      builtins.replaceStrings [ "name: ${leaf}" ] [ "name: modularity-${leaf}" ] original;
  };
in
{
  programs.agent-skills = {
    enable = true;

    sources = {
      mattpocock = {
        input = "skills-mattpocock";
        subdir = "skills";
      };
      impeccable = {
        input = "skills-impeccable";
        subdir = ".agents/skills";
      };
      mutant = {
        input = "skills-mutant";
        subdir = ".";
      };
      modularity = {
        input = "skills-modularity";
        subdir = "skills";
      };
      local = {
        path = ../../skills;
      };
    };

    # Flat names preserved; path points at each skill's location in its source.
    skills.explicit = {
      grill-me = {
        from = "mattpocock";
        path = "productivity/grill-me";
      };
      grilling = {
        from = "mattpocock";
        path = "productivity/grilling";
      };
      handoff = {
        from = "mattpocock";
        path = "productivity/handoff";
      };
      teach = {
        from = "mattpocock";
        path = "productivity/teach";
      };
      writing-great-skills = {
        from = "mattpocock";
        path = "productivity/writing-great-skills";
      };
      codebase-design = {
        from = "mattpocock";
        path = "engineering/codebase-design";
      };
      diagnosing-bugs = {
        from = "mattpocock";
        path = "engineering/diagnosing-bugs";
      };
      domain-modeling = {
        from = "mattpocock";
        path = "engineering/domain-modeling";
      };
      prototype = {
        from = "mattpocock";
        path = "engineering/prototype";
      };
      resolving-merge-conflicts = {
        from = "mattpocock";
        path = "engineering/resolving-merge-conflicts";
      };
      tdd = {
        from = "mattpocock";
        path = "engineering/tdd";
      };
      improve-codebase-architecture = {
        from = "mattpocock";
        path = "engineering/improve-codebase-architecture";
      };
      grill-with-docs = {
        from = "mattpocock";
        path = "engineering/grill-with-docs";
      };
      edit-article = {
        from = "mattpocock";
        path = "personal/edit-article";
      };
      impeccable = {
        from = "impeccable";
        path = "impeccable";
      };
      mutant = {
        from = "mutant";
        path = ".";
      };
      commit = {
        from = "local";
        path = "commit";
      };
      modularity-balanced-coupling = modularitySkill "balanced-coupling";
      modularity-design = modularitySkill "design";
      modularity-document = modularitySkill "document";
      modularity-review = modularitySkill "review";
    };

    targets.claude.enable = true;
    targets.pi.enable = true;
  };
}
