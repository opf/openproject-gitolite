module RepositoryDeploymentCredentialsHelper

  def build_list_of_keys(user_deployment_keys, other_deployment_keys, disabled_deployment_keys)
    option_array = [['Select a deployment key', -1]]
    option_array += user_deployment_keys.map { |key| [keylabel_text(key), key.id] }

    if !other_deployment_keys.empty?
      option_array2 = other_deployment_keys.map { |key| [keylabel_text(key), key.id] }
      maxlen = (option_array + option_array2).map { |x| x.first.length }.max
  
      extra = ([maxlen - 'Other Keys'.length - 2, 6].max) / 2
      option_array += [[('-' * extra) + ' ' + 'Other Keys' + ' ' + ('-' * extra), -2]]
      option_array += option_array2
    end

    options_for_select(option_array, selected: -1, disabled: [-1] + [-2] + disabled_deployment_keys.map(&:id))
  end

end
