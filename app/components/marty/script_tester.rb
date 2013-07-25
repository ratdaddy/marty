class Marty::ScriptTester < Marty::CmFormPanel
  include Marty::Extras::Layout

  def configure(c)
    super

    c.items = [
               fieldset(I18n.t("script_tester.attributes"),
                        {
                          xtype: 	:netzkeremotecombo,
                          name: 	"nodename",
                          attr_type: 	:string,
                          virtual: 	true,
                          field_label: 	"Node",
                        },
                        {
                          xtype: 	:netzkeremotecombo,
                          name: 	"attrname",
                          attr_type: 	:string,
                          virtual: 	true,
                          field_label: 	"Attribute",
                        },
                        {
                          name: 	"attrs",
                          attr_type: 	:text,
                          value: 	"",
                          hide_label: 	true,
                          min_height: 	150,
                        },
                        {},
                        ),
               fieldset(I18n.t("script_tester.parameters"),
                        {
                          xtype: 	:netzkeremotecombo,
                          name: 	"paramname",
                          attr_type: 	:string,
                          virtual: 	true,
                          hide_label: 	true,
                        },
                        {
                          name: 	"params",
                          attr_type: 	:text,
                          value: 	"",
                          hide_label: 	true,
                          min_height: 	100,
                        },
                        {},
                        ),
               :result,
              ]
  end

  js_configure do |c|
    c.select_script = <<-JS
      function(script_id) {
	var me = this;

        me.loadScript({script_id: script_id});

	var form = me.getForm();
	// reload the attr/param drop downs
	form.findField('nodename').store.load({params: {}});
	form.findField('attrname').reset();
	form.findField('attrname').store.load({params: {}});
	form.findField('paramname').store.load({params: {}});
      }
      JS

    c.init_component = <<-JS
      function() {
	var me = this;
        me.callParent();
	var form = me.getForm();

	var nodename 	= form.findField('nodename');
	var attrname 	= form.findField('attrname');
	var attrs 	= form.findField('attrs');
	var paramname 	= form.findField('paramname');
	var params 	= form.findField('params');

      	nodename.on('select', function(combo, record) {
          var data = record[0] && record[0].data;
	  me.selectNode({node: data.text});
	  attrname.reset();
	  attrname.store.load({params: {}});
	});

      	attrname.on('select', function(combo, record) {
	   if (nodename.getValue()) {
 	     attrs.setValue(attrs.getValue() +
		nodename.getDisplayValue() + "." + record[0].data.text + '; ');
           }
	   combo.select(null);
	});

      	paramname.on('select', function(combo, record) {
 	   params.setValue(params.getValue() + record[0].data.text + " = 0.0\\n");
	   combo.select(null);
	});
      }
      JS

    c.set_result = <<-JS
      function(html) {
	var result = this.netzkeGetComponent('result');
	result.updateBodyHtml(html);
      }
      JS

  end

  def node_list
    engine = Marty::ScriptSet.
      get_engine(component_session[:script_id])
    engine ? engine.enumerate_nodes.sort : []
  end

  def attr_list
    engine = Marty::ScriptSet.
      get_engine(component_session[:script_id])
    node = component_session[:selected_node]
    return [] unless node

    engine ? engine.enumerate_attrs_by_node(node).sort : []
  end

  def param_list
    engine = Marty::ScriptSet.get_engine(component_session[:script_id])
    engine.enumerate_params.sort if engine || []
  end

  endpoint :load_script do |params, this|
    component_session[:script_id] = params[:script_id]
    engine = Marty::ScriptSet.get_engine(params[:script_id])
  end

  endpoint :netzke_submit do |params, this|
    data = ActiveSupport::JSON.decode(params[:data])

    attrs = data["attrs"].split(';').map(&:strip).reject(&:empty?)

    pjson = data["params"].split("\n").map(&:strip).reject(&:empty?).map {
      |s| s.sub(/^([a-z0-9_]*)\s*=/, '"\1": ')
    }.join(',')

    begin
      phash = ActiveSupport::JSON.decode("{ #{pjson} }")
    rescue MultiJson::DecodeError
      this.netzke_feedback "Malformed input parameters"
      return
    end

    engine = Marty::ScriptSet.get_engine(component_session[:script_id])

    begin
      result = attrs.map { |a|
        node, attr = a.split('.')
        raise "bad attribute: '#{a}'" if !attr
        # Need to clone phash since it's modified by eval.  It can
        # be reused for a given node but not across nodes.
        res = engine.evaluate(node, attr, phash.clone)
        q = CGI::escapeHTML(res.to_json)
        "#{a} = #{q}"
      }

      this.netzke_feedback "done"
      this.set_result result.join("<br/>")
    rescue => exc
      err, bt = engine.parse_runtime_exception(exc)

      result = ["Error: #{err}", "Backtrace:"] +
        bt.map {|m, line, fn| "#{m}:#{line} #{fn}"}

      this.netzke_feedback "failed"
      this.set_result '<font color="red">' + result.join("<br/>") + "</font>"
    end
  end

  def combofy(l)
    l.each_with_index.map {|x, i| [i+1, x]}
  end

  endpoint :select_node do |params, this|
    component_session[:selected_node] = params[:node]
  end

  endpoint :get_combobox_options do |params, this|
    this.data = case params["attr"]
                when "nodename" then
                  combofy(node_list)
                when "attrname" then
                  combofy(attr_list)
                when "paramname"
                  combofy(param_list)
                end
  end

  action :apply do |a|
    a.text 	= I18n.t("script_tester.compute")
    a.tooltip  	= I18n.t("script_tester.compute")
    a.icon 	= :script_go
    a.disabled 	= false
  end

  component :result do |c|
    c.klass 		= Marty::CmPanel
    c.title 		= I18n.t("script_tester.results")
    c.html 		= ""
    c.flex 		= 1
    c.min_height 	= 150
    c.auto_scroll 	= true
  end

end

ScriptTester = Marty::ScriptTester
