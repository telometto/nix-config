{
  prometheusQuery =
    {
      expr,
      from ? 600,
      intervalMs ? 60000,
    }:
    {
      refId = "A";
      datasourceUid = "prometheus";
      relativeTimeRange = {
        inherit from;
        to = 0;
      };
      model = {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        refId = "A";
        inherit expr intervalMs;
        instant = true;
        range = false;
        editorMode = "code";
        maxDataPoints = 43200;
      };
    };

  threshold = {
    refId = "B";
    datasourceUid = "__expr__";
    relativeTimeRange = {
      from = 0;
      to = 0;
    };
    model = {
      refId = "B";
      type = "threshold";
      expression = "A";
      conditions = [
        {
          evaluator = {
            type = "gt";
            params = [ 0 ];
          };
          operator.type = "and";
          query.params = [ "B" ];
          reducer = {
            type = "last";
            params = [ ];
          };
          type = "query";
        }
      ];
    };
  };
}
