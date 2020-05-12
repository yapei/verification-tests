@clusterlogging
Feature: collector related tests

  # @author qitang@redhat.com
  # @case_id OCP-25767
  @admin
  @destructive
  @commonlogging
  Scenario: All nodes logs are sent to Elasticsearch
    Given the master version == "4.1"
    Given evaluation of `cluster_logging('instance').fluentd_ready_pods.map(&:ip)` is stored in the :collector_pod_ips clipboard
    #A workaround to https://bugzilla.redhat.com/show_bug.cgi?id=1776594
    And I wait for the ".operations" index to appear in the ES pod with labels "es-node-master=true"
    Given I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | .operations.* |
      | op           | DELETE        |
    Then the step should succeed
    Given I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | project.* |
      | op           | DELETE    |
    Then the step should succeed
    #Workaround end
    And I wait for the ".operations" index to appear in the ES pod with labels "es-node-master=true"
    Given I get the ".operations" logging index information from a pod with labels "es-node-master=true"
    And the expression should be true> cb.index_data['docs.count'] > "0"
    Given I wait up to 300 seconds for the steps to pass:
    """
    Then I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _search?pretty&size=0' -d'{"aggs" : {"exists_field_kubernetes" : {"filter": {"exists": {"field":"kubernetes"}},"aggs" : {"distinct_fluentd_ip" : {"terms" : {"field" : "pipeline_metadata.collector.ipaddr4"}}}}}} |
      | op           | GET     |
    Then the step should succeed

    Given evaluation of `JSON.parse(@result[:response])['aggregations']['exists_field_kubernetes']['distinct_fluentd_ip']['buckets'].map {|furn| furn["key"]}` is stored in the :kuber_ips clipboard
    And the expression should be true> Set.new(cb.collector_pod_ips) == Set.new(cb.kuber_ips)

    And I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _search?pretty&size=0' -d'{"aggs" : {"exists_field_systemd" : {"filter": {"exists": {"field":"systemd"}},"aggs" : {"distinct_fluentd_ip" : {"terms" : {"field" : "pipeline_metadata.collector.ipaddr4"}}}}}} |
      | op           | GET   |
    Then the step should succeed
    Given evaluation of `JSON.parse(@result[:response])['aggregations']['exists_field_systemd']['distinct_fluentd_ip']['buckets'].map {|furn| furn["key"]}` is stored in the :journal_ips clipboard
    And the expression should be true> Set.new(cb.collector_pod_ips) == Set.new(cb.journal_ips)
    """

  # @author qitang@redhat.com
  # @case_id OCP-24837
  @admin
  @destructive
  @commonlogging
  Scenario: All nodes logs had sent logs to Elasticsearch
    Given the master version >= "4.2"
    Given evaluation of `cluster_logging('instance').collection_type` is stored in the :collection_type clipboard
    Given <%= daemon_set(cb.collection_type).replica_counters[:desired] %> pods become ready with labels:
      | component=<%= cb.collection_type %> |
    And evaluation of `@pods.map {|n| n.node_ip}.uniq` is stored in the :node_ips clipboard
    #And evaluation of `cluster_logging('instance').fluentd_ready_pods.map(&:node_ip)` is stored in the :node_ips clipboard
    #A workaround to https://bugzilla.redhat.com/show_bug.cgi?id=1776594
    And I wait for the ".operations" index to appear in the ES pod with labels "es-node-master=true"
    Given I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | .operations.* |
      | op           | DELETE        |
    Then the step should succeed
    Given I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | project.* |
      | op           | DELETE     |
    Then the step should succeed
    #Workaround end
    
    Given I wait for the ".operations" index to appear in the ES pod with labels "es-node-master=true"
    Then I get the ".operations" logging index information from a pod with labels "es-node-master=true"
    And the expression should be true> cb.index_data['docs.count'] > "0"

    Given I wait up to 300 seconds for the steps to pass:
    """
    Then I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _search?pretty&size=0' -d'{"aggs" : {"exists_field_kubernetes" : {"filter": {"exists": {"field":"kubernetes"}},"aggs" : {"distinct_node_ip" : {"terms" : {"field" : "pipeline_metadata.collector.ipaddr4"}}}}}} |
      | op           | GET   |
    Then the step should succeed
    Given evaluation of `JSON.parse(@result[:response])['aggregations']['exists_field_kubernetes']['distinct_node_ip']['buckets'].map {|furn| furn["key"]}` is stored in the :kuber_ips clipboard
    And the expression should be true> Set.new(cb.node_ips) == Set.new(cb.kuber_ips)

    And I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _search?pretty&size=0' -d'{"aggs" : {"exists_field_systemd" : {"filter": {"exists": {"field":"systemd"}},"aggs" : {"distinct_node_ip" : {"terms" : {"field" : "pipeline_metadata.collector.ipaddr4"}}}}}} |
      | op           | GET  |
    Then the step should succeed
    Given evaluation of `JSON.parse(@result[:response])['aggregations']['exists_field_systemd']['distinct_node_ip']['buckets'].map {|furn| furn["key"]}` is stored in the :journal_ips clipboard
    And the expression should be true> Set.new(cb.node_ips) == Set.new(cb.journal_ips)
    """

  # @author qitang@redhat.com
  @admin
  @destructive
  @commonlogging
  Scenario Outline: The System Journald log can be collected
    Given evaluation of `cluster_logging('instance').collection_type` is stored in the :collection_type clipboard
    And I wait for the "<index_name>" index to appear in the ES pod with labels "es-node-master=true"
    Then the step should succeed
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | <index_name>*/_search?pretty'  -d '{"query": {"exists": {"field": "systemd"}}} |
      | op           | GET                                                                            |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['name'] == cb.collection_type
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['inputname'] == (cb.collection_type == "fluentd" ? "fluent-plugin-systemd" : "imfile")

    Examples:
      | index_name  |
      | .operations | # @case_id OCP-25365
      | infra       | # @case_id OCP-30083

  # @author qitang@redhat.com
  # @case_id OCP-18147
  @admin
  @destructive
  @commonlogging
  Scenario: The Container logs metadata check
    Given the master version == "4.1"
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project` is stored in the :proj clipboard
    When I run the :new_app client command with:
      | file | <%= BushSlicer::HOME %>/testdata/logging/loggen/container_json_unicode_log_template.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given evaluation of `pod` is stored in the :log_pod clipboard
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    Given evaluation of `cluster_logging('instance').fluentd_ready_pods.map(&:ip)` is stored in the :collector_pod_ips clipboard
    And I wait for the "project.<%= cb.proj.name %>" index to appear in the ES pod with labels "es-node-master=true"
    Then the step should succeed
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | project.<%= cb.proj.name %>.*/_search?pretty |
      | op           | GET                                          |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['message'] == "ㄅㄉˇˋㄓˊ˙ㄚㄞㄢㄦㄆ 中国 883.317µs ā á ǎ à ō ó ▅ ▆ ▇ █ 々"
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['name'] == "fluentd"
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['inputname'] == "fluent-plugin-systemd"
    And the expression should be true> cb.collector_pod_ips.include? @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['ipaddr4']
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['ipaddr6'] != nil
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['docker']['container_id'] == cb.log_pod.container(user: user, name: 'centos-logtest').id
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['kubernetes']['container_name'] == "centos-logtest"
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['kubernetes']['namespace_name'] == cb.proj.name
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['kubernetes']['pod_name'] == cb.log_pod.name

  # @author qitang@redhat.com
  # @case_id OCP-25768
  @admin
  @destructive
  @commonlogging
  Scenario: The container logs metadata check
    Given the master version >= "4.2"
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project` is stored in the :proj clipboard
    When I run the :new_app client command with:
      | file | <%= BushSlicer::HOME %>/testdata/logging/loggen/container_json_unicode_log_template.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given evaluation of `pod` is stored in the :log_pod clipboard
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    Given evaluation of `cluster_logging('instance').collection_type` is stored in the :collection_type clipboard
    Given I wait up to 300 seconds for the steps to pass:
    """
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | */_search?pretty' -d '{"query": {"match": {"kubernetes.namespace_name": "<%= cb.proj.name %>"}}} |
      | op           | GET                                                                                              |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['message'] == "ㄅㄉˇˋㄓˊ˙ㄚㄞㄢㄦㄆ 中国 883.317µs ā á ǎ à ō ó ▅ ▆ ▇ █ 々"
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['name'] == cb.collection_type
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['inputname'] == (cb.collection_type == "fluentd" ? "fluent-plugin-systemd" : "imfile")
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['ipaddr4'] == cb.log_pod.node_ip
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['docker']['container_id'] == cb.log_pod.container(user: user, name: 'centos-logtest').id
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['kubernetes']['container_name'] == "centos-logtest"
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['kubernetes']['namespace_name'] == cb.proj.name
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['kubernetes']['pod_name'] == cb.log_pod.name
    """

  # @author qitang@redhat.com
  # @case_id OCP-30084
  @admin
  @destructive
  @commonlogging
  Scenario: All nodes logs had sent logs to Elasticsearch
    Given the master version >= "4.5"
    Given evaluation of `cluster_logging('instance').collection_type` is stored in the :collection_type clipboard
    Given <%= daemon_set(cb.collection_type).replica_counters[:desired] %> pods become ready with labels:
      | component=<%= cb.collection_type %> |
    And evaluation of `@pods.map {|n| n.node_ip}.uniq` is stored in the :node_ips clipboard
    Given I wait for the "infra" index to appear in the ES pod with labels "es-node-master=true"
    Then I get the "infra" logging index information from a pod with labels "es-node-master=true"
    And the expression should be true> cb.index_data['docs.count'] > "0"

    Given I wait up to 300 seconds for the steps to pass:
    """
    Then I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _search?pretty&size=0' -d'{"aggs" : {"exists_field_kubernetes" : {"filter": {"exists": {"field":"kubernetes"}},"aggs" : {"distinct_node_ip" : {"terms" : {"field" : "pipeline_metadata.collector.ipaddr4"}}}}}} |
      | op           | GET   |
    Then the step should succeed
    Given evaluation of `JSON.parse(@result[:response])['aggregations']['exists_field_kubernetes']['distinct_node_ip']['buckets'].map {|furn| furn["key"]}` is stored in the :kuber_ips clipboard
    And the expression should be true> Set.new(cb.node_ips) == Set.new(cb.kuber_ips)

    And I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _search?pretty&size=0' -d'{"aggs" : {"exists_field_systemd" : {"filter": {"exists": {"field":"systemd"}},"aggs" : {"distinct_node_ip" : {"terms" : {"field" : "pipeline_metadata.collector.ipaddr4"}}}}}} |
      | op           | GET  |
    Then the step should succeed
    Given evaluation of `JSON.parse(@result[:response])['aggregations']['exists_field_systemd']['distinct_node_ip']['buckets'].map {|furn| furn["key"]}` is stored in the :journal_ips clipboard
    And the expression should be true> Set.new(cb.node_ips) == Set.new(cb.journal_ips)
    """
