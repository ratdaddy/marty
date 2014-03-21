class Marty::PromiseView < Marty::TreePanel
  css_configure do |c|
    c.require :promise_view
  end

  js_configure do |c|
    c.default_get_row_class = <<-JS
    function(record, index, rowParams, ds) {
       var status = record.get('status');
       if (status === false) return "red-row";
       if (status === true)  return "green-row";
       return "orange-row";
    }
    JS
  end

  def configure(c)
    c.title = I18n.t("jobs.promise_view")
    c.model = "Marty::Promise"
    c.columns = [
                 :parent,
                 :user__login,
                 :job_id,
                 :start_dt,
                 :end_dt,
                 :status,
                 :cformat,
                 :error,
                ]
    c.treecolumn = :parent
    super

    c.data_store.sorters = {
      property: "id",
      direction: 'DESC',
    }

    # garbage collect old promises (hacky to do this here)
    Marty::Promise.cleanup
  end

  def bbar
    ['->', :refresh, :download]
  end

  js_configure do |c|
    c.init_component = <<-JS
    function() {
       this.callParent();
       this.getSelectionModel().on('selectionchange', function(selModel) {
          this.actions.download &&
          this.actions.download.setDisabled(!selModel.hasSelection());
       }, this);
    }
    JS

    c.on_download = <<-JS
    function() {
       var jid = this.getSelectionModel().selected.first().getId();
       // FIXME: seems pretty hacky
       window.location = "#{Marty::Util.marty_path}/job/download?job_id=" + jid;
    }
    JS

    c.on_refresh = <<-JS
    function() {
       this.store.load();
    }
    JS
  end

  action :download do |a|
    a.text     = a.tooltip = 'Download'
    a.disabled = true
    a.icon     = :application_put
  end

  action :refresh do |a|
    a.text     = a.tooltip = 'Refresh'
    a.disabled = false
    a.icon     = :arrow_refresh
  end

  def get_children(params)
    params[:scope] = config[:scope]

    parent_id = params[:id]
    parent_id = nil if parent_id == 'root'

    scope_data_class(params) do
      data_class.where(parent_id: parent_id).scoping do
        data_adapter.get_records(params, final_columns)
      end
    end
  end

  column :parent do |c|
    c.text   = 'Job Name'
    c.getter = lambda { |r| r.title }
    c.width  = 275
  end

  column :status do |c|
    c.hidden = true
    # FIXME: TreePanel appears to not work with hidden boolean cols
    c.xtype  = 'numbercolumn'
  end

  column :user__login do |c|
    c.text   = I18n.t('jobs.user_login')
  end

  column :start_dt do |c|
    c.text   = I18n.t('jobs.start_dt')
  end

  column :end_dt do |c|
    c.text   = I18n.t('jobs.end_dt')
  end

  column :error do |c|
    c.getter = lambda {|r| r.result.to_s if r.status == false}
    c.flex   = 1
  end

  column :cformat do |c|
    c.text   = "Format"
  end

end

PromiseView = Marty::PromiseView
