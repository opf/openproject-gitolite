module RepositoryMirrorsHelper

  # Mirror Mode
  def mirror_mode(mirror)
    if mirror.active==0
      "Inactive"
    else
      ["Mirror","Forced","Unforced"][mirror.push_mode]
    end
  end

  # Refspec for mirrors
  def refspec(mirror, max_refspec=0)
    if mirror.mirror_mode?
     "All refs"
    else
      result=[]
      result << "All branches" if mirror.include_all_branches
      result << "All tags" if mirror.include_all_tags
      result << mirror.explicit_refspec if (max_refspec == 0) || ((1..max_refspec) === mirror.explicit_refspec.length)
      result << "Explicit" if (max_refspec > 0) && (mirror.explicit_refspec.length > max_refspec)
      result .join('<br/>')
    end
  end

  # Port-receive Mode
  def post_receive_mode(prurl)
    if prurl.active==0
      "Inactive"
    elsif prurl.mode == :github
      "GitHub POST"
    else
      "Empty GET"
    end
  end
  


end