{ ref }:
{
  owner = "codgi";
  content = ''
    access-tokens = github.com=${ref "github-access-token"}
  '';
}
