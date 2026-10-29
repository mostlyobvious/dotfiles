{ ... }:

{
  programs.agent-skills = {
    enable = true;

    sources = {
      mattpocock = {
        input = "skills-mattpocock";
        subdir = "skills";
      };
      mutant = {
        input = "skills-mutant";
        subdir = ".";
      };
      local = {
        path = ../skills;
      };
    };

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
      writing-for-agents = {
        from = "mattpocock";
        path = "productivity/writing-for-agents";
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
      mutant = {
        from = "mutant";
        path = ".";
      };
      mutmut = {
        from = "local";
        path = "mutmut";
      };
      change-writing = {
        from = "local";
        path = "change-writing";
      };
      commit = {
        from = "local";
        path = "commit";
      };
      merge-request = {
        from = "local";
        path = "merge-request";
      };
      merge-stack = {
        from = "local";
        path = "merge-stack";
      };
      my-mrs = {
        from = "local";
        path = "my-mrs";
      };
      rebase-stack = {
        from = "local";
        path = "rebase-stack";
      };
      review-ccc = {
        from = "local";
        path = "review-ccc";
      };
      review-wewut = {
        from = "local";
        path = "review-wewut";
      };
      worktree-cleanup = {
        from = "local";
        path = "worktree-cleanup";
      };
    };

    targets.claude.enable = true;
    targets.pi.enable = true;
  };
}
