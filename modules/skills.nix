{ ... }:

{
  programs.agent-skills = {
    enable = true;

    sources = {
      mattpocock = {
        input = "skills-mattpocock";
        subdir = "skills";
      };
      mutant.input = "skills-mutant";
      local = {
        path = ../skills;
        filter.maxDepth = 1;
      };
    };

    skills.enableAll = [ "local" ];

    skills.explicit = {
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
      mutant = {
        from = "mutant";
        path = ".";
      };
    };

    targets.claude.enable = true;
    targets.pi.enable = true;
  };
}
