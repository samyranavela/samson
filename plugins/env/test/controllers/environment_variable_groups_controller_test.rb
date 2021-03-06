# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe EnvironmentVariableGroupsController do
  def self.it_updates
    it "updates" do
      variable = env_group.environment_variables.first
      refute_difference "EnvironmentVariable.count" do
        put :update, params: {
          id: env_group.id,
          environment_variable_group: {
            environment_variables_attributes: {
              "0" => {name: "N1", value: "V2", scope_type_and_id: "DeployGroup-#{deploy_group.id}", id: variable.id}
            }
          }
        }
      end

      assert_redirected_to "/environment_variable_groups"
      variable.reload.value.must_equal "V2"
      variable.reload.scope.must_equal deploy_group
    end
  end

  def self.it_destroys
    it "destroy" do
      env_group
      assert_difference "EnvironmentVariableGroup.count", -1 do
        delete :destroy, params: {id: env_group.id}
      end
      assert_redirected_to "/environment_variable_groups"
    end
  end

  let(:stage) { stages(:test_staging) }
  let(:project) { stage.project }
  let(:deploy_group) { stage.deploy_groups.first }
  let!(:env_group) do
    EnvironmentVariableGroup.create!(
      name: "G1",
      environment_variables_attributes: {
        0 => {name: "X", value: "Y"},
        1 => {name: "Y", value: "Z"}
      }
    )
  end
  let(:other_project) do
    p = project.dup
    p.name = 'xxxxx'
    p.permalink = 'xxxxx'
    p.save!(validate: false)
    p
  end

  as_a_viewer do
    before do
      env_group
      env_group.update_column :id, 1 # need static id
    end

    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :patch, :update, id: 1
    unauthorized :delete, :destroy, id: 1

    describe "#index" do
      it "renders" do
        get :index
        assert_response :success
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: env_group.id}
        assert_response :success
      end
    end

    describe "#preview" do
      it "renders for groups" do
        get :preview, params: {group_id: env_group.id}
        assert_response :success
      end

      it "renders for projects" do
        get :preview, params: {project_id: project.id}
        assert_response :success
      end

      it "calls env with preview" do
        EnvironmentVariable.expects(:env).with(anything, anything, preview: true).times(3)
        get :preview, params: {group_id: env_group.id}
        assert_response :success
      end
    end
  end

  as_a_project_admin do
    describe "#new" do
      it "renders" do
        get :new
        assert_response :success
      end
    end

    describe "#create" do
      it "creates" do
        assert_difference "EnvironmentVariable.count", +1 do
          assert_difference "EnvironmentVariableGroup.count", +1 do
            post :create, params: {
              environment_variable_group: {
                environment_variables_attributes: {"0" => {name: "N1", value: "V1"}},
                name: "G2"
              }
            }
          end
        end
        assert_redirected_to "/environment_variable_groups"
      end
    end

    describe "#update" do
      let(:params) do
        {
          id: env_group.id,
          environment_variable_group: {
            name: "G2",
            comment: "COOMMMENT",
            environment_variables_attributes: {
              "0" => {name: "N1", value: "V1"}
            }
          }
        }
      end

      before { env_group }

      it "adds" do
        assert_difference "EnvironmentVariable.count", +1 do
          put :update, params: params
        end

        assert_redirected_to "/environment_variable_groups"
        env_group.reload
        env_group.name.must_equal "G2"
        env_group.comment.must_equal "COOMMMENT"
      end

      it_updates

      it "destroys variables" do
        variable = env_group.environment_variables.first
        assert_difference "EnvironmentVariable.count", -1 do
          put :update, params: {
            id: env_group.id, environment_variable_group: {
              environment_variables_attributes: {
                "0" => {name: "N1", value: "V2", id: variable.id, _destroy: true}
              }
            }
          }
        end

        assert_redirected_to "/environment_variable_groups"
      end

      it 'updates when the group is used by a project where the user is an admin' do
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: project)
        assert_difference "EnvironmentVariable.count", +1 do
          put :update, params: params
        end
      end

      it "cannot update when not an admin for any used projects" do
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: other_project)
        put :update, params: params
        assert_response :unauthorized
      end

      it "cannot update when not an admin for some used projects" do
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: project)
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: other_project)
        put :update, params: params
        assert_response :unauthorized
      end
    end

    describe "#destroy" do
      it_destroys

      it "cannot destroy when not an admin for all used projects" do
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: other_project)
        delete :destroy, params: {id: env_group.id}
        assert_response :unauthorized
      end
    end
  end

  as_an_admin do
    describe "#update" do
      before { env_group }
      it_updates
    end

    describe "#destroy" do
      it_destroys
    end
  end
end
