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
      mutant = {
        from = "mutant";
        path = ".";
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
    };

    targets.claude.enable = true;
    targets.pi.enable = true;
  };
}
